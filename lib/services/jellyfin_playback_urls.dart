String buildJellyfinDirectStreamUrl({
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

String buildJellyfinTrickplayTileUrl({
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
