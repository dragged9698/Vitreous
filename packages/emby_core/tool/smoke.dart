import 'dart:io';

import 'package:emby_core/emby_core.dart';

/// CLI smoke test: authenticate and print library views.
///
/// Usage:
///   EMBY_SERVER_URL=http://host:8096 EMBY_USERNAME=user EMBY_PASSWORD=pass dart run tool/smoke.dart
Future<void> main() async {
  final serverUrl = Platform.environment['EMBY_SERVER_URL'];
  final username = Platform.environment['EMBY_USERNAME'];
  final password = Platform.environment['EMBY_PASSWORD'] ?? '';

  if (serverUrl == null || username == null) {
    stderr.writeln('Set EMBY_SERVER_URL and EMBY_USERNAME (optional EMBY_PASSWORD)');
    exit(1);
  }

  final repo = InMemoryAuthRepository();
  print('Probing $serverUrl ...');
  final auth = EmbyAuthService();
  final info = await auth.probePublic(serverUrl);
  print('Server: ${info['ServerName'] ?? info['ProductName']} (${info['Version']})');

  print('Authenticating as $username ...');
  final result = await repo.authenticate(serverUrl, username, password);
  final token = result.accessToken;
  final userId = result.user?.id;
  if (token == null || userId == null) {
    stderr.writeln('Authentication failed: missing token or user id');
    exit(2);
  }
  print('Authenticated userId=$userId');

  final dio = DioFactory.createWithContext(
    baseUrl: serverUrl,
    context: EmbyRequestContext(),
    accessToken: token,
  );
  final api = EmbyApiService(dio: dio, userId: userId);
  final views = await api.getViews();
  print('Libraries (${views.totalRecordCount}):');
  for (final lib in views.items) {
    print('  - ${lib.name} (${lib.id})');
  }
}
