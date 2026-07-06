/// When Emby's PlaybackInfo says the player must use HLS transcode instead of
/// a direct HTTP stream.
///
/// [RequiresOpening] only means the server opens the file handle (symlinks,
/// decypharr mounts, etc.) — Emby still serves those via DirectStreamUrl.
/// Trust SupportsDirectPlay/SupportsDirectStream like Emby desktop does.
bool embySourceNeedsTranscode(Map<String, dynamic> source) {
  final supportsDirectPlay = source['SupportsDirectPlay'] as bool? ?? true;
  final supportsDirectStream = source['SupportsDirectStream'] as bool? ?? true;
  return !supportsDirectPlay || !supportsDirectStream;
}

bool embySourceSupportsDirectStream(Map<String, dynamic> source) {
  return source['SupportsDirectStream'] as bool? ?? true;
}

/// Item-level MediaSource flags (pre-negotiation) — stable for remuxes the
/// server wrongly caps with ContainerBitrateExceedsLimit during PlaybackInfo.
bool embyBundleSupportsDirectPlayback(Map<String, dynamic> source) {
  final supportsDirectPlay = source['SupportsDirectPlay'] as bool? ?? true;
  final supportsDirectStream = source['SupportsDirectStream'] as bool? ?? true;
  return supportsDirectPlay && supportsDirectStream;
}

/// Bitrate sent on PlaybackInfo for original quality. Omitting/null lets Emby
/// apply a low default and return HLS for remuxes (ContainerBitrateExceedsLimit).
const int embyOriginalPlaybackBitrate = 1_000_000_000;

/// Emby sometimes puts an HLS master playlist in DirectStreamUrl when it
/// decided to transcode — that is not a progressive direct stream.
bool embyUrlLooksLikeHlsTranscode(String? url) {
  if (url == null || url.isEmpty) return false;
  final lower = url.toLowerCase();
  return lower.contains('.m3u8') ||
      lower.contains('master.') ||
      lower.contains('/hls/') ||
      lower.contains('transcodereasons=');
}

bool embyIsProgressiveDirectStreamUrl(String? url) {
  return url != null && url.isNotEmpty && !embyUrlLooksLikeHlsTranscode(url);
}

/// Picks the HLS URL Emby returned for a capped transcode (sometimes only in
/// [directStreamUrl] when mislabeled).
String? embyPickHlsTranscodeUrl(Object? transcodingUrl, Object? directStreamUrl) {
  if (transcodingUrl is String && embyUrlLooksLikeHlsTranscode(transcodingUrl)) return transcodingUrl;
  if (directStreamUrl is String && embyUrlLooksLikeHlsTranscode(directStreamUrl)) return directStreamUrl;
  return null;
}

/// Virtual/debrid library paths that need `/LiveStreams/Open` or progressive
/// streaming instead of `Static=true` byte-range reads.
bool embySourceMustDirectStream(Map<String, dynamic> source) {
  if (embySourceNeedsLiveStreamOpen(source)) return true;
  final path = (source['Path'] as String?)?.toLowerCase() ?? '';
  return path.endsWith('.strm');
}

/// Fill gaps in the negotiated source from the item's cached MediaSource.
Map<String, dynamic> enrichEmbyMediaSource(
  Map<String, dynamic> negotiated,
  Map<String, dynamic> itemSource,
) {
  final merged = Map<String, dynamic>.from(negotiated);
  final negotiatedPath = merged['Path'] as String?;
  if (negotiatedPath == null || negotiatedPath.isEmpty) {
    final path = itemSource['Path'];
    if (path is String && path.isNotEmpty) merged['Path'] = path;
  }
  if (merged['OpenToken'] == null) {
    final token = itemSource['OpenToken'];
    if (token is String && token.isNotEmpty) merged['OpenToken'] = token;
  }
  return merged;
}

/// Virtual/debrid library paths that need `/LiveStreams/Open` or progressive
/// streaming instead of `Static=true` byte-range reads.
bool embySourceLooksVirtualPath(Map<String, dynamic> source) {
  final path = (source['Path'] as String?)?.toLowerCase() ?? '';
  if (path.isEmpty) return false;
  const markers = ['decypharr', 'blackhole', 'rclone', '.fuse', 'debrid', 'zurg'];
  return markers.any(path.contains);
}

/// Sources that must call `/LiveStreams/Open` before playback (official Emby
/// Kodi plugin does the same when [RequiresOpening] is set).
bool embySourceNeedsLiveStreamOpen(Map<String, dynamic> source) {
  if (source['RequiresOpening'] as bool? ?? false) return true;
  final openToken = source['OpenToken'] as String?;
  if (openToken != null && openToken.isNotEmpty) return true;
  return embySourceLooksVirtualPath(source);
}

/// Whether `/Videos/{id}/stream` should use `Static=true` (byte-range file read).
///
/// Vitreous is always a network client — only the Emby server process can safely
/// static-read bind mounts. Virtual mounts need progressive server-side reads.
bool embySourcePrefersStaticStream(Map<String, dynamic> source) {
  if (embySourceNeedsLiveStreamOpen(source)) return false;
  if (source['IsRemote'] as bool? ?? false) return false;
  final size = source['Size'];
  if (size is! num || size <= 0) return false;
  // Remote streaming: never byte-range static reads.
  return false;
}

/// Auth headers MPV must send alongside `api_key` — reverse proxies in front
/// of Emby/Jellyfin often reject bare query tokens.
Map<String, String> mediaBrowserStreamHeaders(Map<String, String> defaultHeaders) {
  final headers = <String, String>{};
  final auth = defaultHeaders['Authorization'];
  final token = defaultHeaders['X-Emby-Token'];
  if (auth != null && auth.isNotEmpty) headers['Authorization'] = auth;
  if (token != null && token.isNotEmpty) headers['X-Emby-Token'] = token;
  return headers;
}
