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

/// Whether `/Videos/{id}/stream` should use `Static=true` (byte-range file read).
///
/// Virtual mounts (decypharr, FUSE, remote libraries) need the server to open
/// the file and stream progressively — `Static=true` reports a fixed [Size]
/// and MPV/ffmpeg hits EOF mid-read when the mount lies about length.
bool embySourcePrefersStaticStream(Map<String, dynamic> source) {
  if (source['RequiresOpening'] as bool? ?? false) return false;
  if (source['IsRemote'] as bool? ?? false) return false;
  final size = source['Size'];
  if (size is! num || size <= 0) return false;
  return true;
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
