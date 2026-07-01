/// Build the `MediaBrowser` Authorization header value the way the Emby
/// SDK formats it. Used at auth time and on every authenticated request so
/// the server sees a consistent client identity.
String buildEmbyAuthHeader({
  required String clientName,
  required String clientVersion,
  required String deviceName,
  required String deviceId,
  String? accessToken,
}) {
  final parts = <String>[
    'Client="$clientName"',
    'Device="$deviceName"',
    'DeviceId="$deviceId"',
    'Version="$clientVersion"',
    if (accessToken != null && accessToken.isNotEmpty) 'Token="$accessToken"',
  ];
  return 'MediaBrowser ${parts.join(', ')}';
}
