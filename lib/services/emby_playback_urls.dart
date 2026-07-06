String buildEmbyDirectStreamUrl({
  required String baseUrl,
  required String accessToken,
  required String deviceId,
  required String itemId,
  String? container,
  String? mediaSourceId,
  String? playSessionId,
  String? liveStreamId,
  int? audioStreamIndex,
  bool staticStream = true,
}) {
  final params = <String, String>{
    if (staticStream) 'Static': 'true',
    'api_key': accessToken,
    'DeviceId': deviceId,
    'Container': ?container,
    'MediaSourceId': ?mediaSourceId,
    'PlaySessionId': ?playSessionId,
    'LiveStreamId': ?liveStreamId,
    'AudioStreamIndex': ?audioStreamIndex?.toString(),
  };
  final encodedItem = Uri.encodeComponent(itemId);
  final containerExt = container?.trim().toLowerCase();
  final streamPath = !staticStream && containerExt != null && containerExt.isNotEmpty
      ? '/Videos/$encodedItem/stream.$containerExt'
      : '/Videos/$encodedItem/stream';
  return '$baseUrl$streamPath?${_encodeQuery(params)}';
}

String buildEmbyTrickplayTileUrl({
  required String baseUrl,
  required String accessToken,
  required String deviceId,
  required String itemId,
  required int width,
  required int sheetIndex,
  String? mediaSourceId,
}) {
  final params = <String, String>{'api_key': accessToken, 'DeviceId': deviceId, 'MediaSourceId': ?mediaSourceId};
  final encodedItem = Uri.encodeComponent(itemId);
  return '$baseUrl/Videos/$encodedItem/Trickplay/$width/$sheetIndex.jpg?${_encodeQuery(params)}';
}

String _encodeQuery(Map<String, String> params) =>
    params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');

/// Ensures Emby HLS transcode URLs carry the negotiated [startTimeTicks].
///
/// PlaybackInfo may return a stale `StartTimeTicks` when a direct-stream
/// session is still active (quality switch mid-playback). The player does not
/// seek Emby transcodes — it relies on the server offset plus a timeline
/// offset — so the URL must match the requested resume position.
String embyWithTranscodeStartTimeTicks(String url, int? startTimeTicks) {
  if (startTimeTicks == null || startTimeTicks <= 0) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final params = Map<String, String>.from(uri.queryParameters);
  params['StartTimeTicks'] = startTimeTicks.toString();
  return uri.replace(queryParameters: params).toString();
}

/// Aligns negotiated `DirectStreamUrl` with [staticStream] — drop `Static=true`
/// for progressive server-side reads on virtual/symlink mounts.
String sanitizeMediaBrowserDirectStreamUrl(String url, {required bool staticStream}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  final params = Map<String, String>.from(uri.queryParameters);
  if (staticStream) {
    params['Static'] = 'true';
  } else {
    params.remove('Static');
  }
  return uri.replace(queryParameters: params).toString();
}

/// Resolves the best playable URL from Emby PlaybackInfo (direct URL first).
String? resolveEmbyStreamUrl({
  required String baseUrl,
  required String accessToken,
  required String itemId,
  String? directStreamUrl,
  String? transcodingUrl,
  String? mediaSourceId,
  String? playSessionId,
}) {
  if (directStreamUrl != null && directStreamUrl.isNotEmpty) return directStreamUrl;
  if (transcodingUrl != null && transcodingUrl.isNotEmpty) return transcodingUrl;
  return buildEmbyDirectStreamUrl(
    baseUrl: baseUrl,
    accessToken: accessToken,
    deviceId: 'emby-player',
    itemId: itemId,
    mediaSourceId: mediaSourceId,
    playSessionId: playSessionId,
  );
}
