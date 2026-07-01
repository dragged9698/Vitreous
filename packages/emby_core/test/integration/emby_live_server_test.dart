import 'dart:io';

import 'package:dio/dio.dart';
import 'package:emby_core/emby_core.dart';
import 'package:test/test.dart';

/// Live-server integration ladder (gated by environment variables).
///
/// Run:
///   EMBY_SERVER_URL=... EMBY_USERNAME=... EMBY_PASSWORD=... dart test test/integration/emby_live_server_test.dart
void main() {
  final serverUrl = Platform.environment['EMBY_SERVER_URL'];
  final username = Platform.environment['EMBY_USERNAME'];
  final password = Platform.environment['EMBY_PASSWORD'] ?? '';

  if (serverUrl == null || username == null) {
    test('live server ladder (skipped — set EMBY_SERVER_URL and EMBY_USERNAME)', () {},
        skip: 'Missing env vars');
    return;
  }

  late String accessToken;
  late String userId;
  late EmbyApiService api;
  late Dio dio;

  setUpAll(() async {
    HttpOverrides.global = null;
    final auth = EmbyAuthService();
    await auth.probePublic(serverUrl);

    final repo = InMemoryAuthRepository();
    final result = await repo.authenticate(serverUrl, username, password);
    accessToken = result.accessToken!;
    userId = result.user!.id!;

    dio = DioFactory.createWithContext(
      baseUrl: serverUrl,
      context: EmbyRequestContext(),
      accessToken: accessToken,
    );
    api = EmbyApiService(dio: dio, userId: userId);
  });

  test('1 GET /System/Info/Public', () async {
    final response = await dio.get<Map<String, dynamic>>(EmbyEndpoints.systemInfoPublic);
    expect(response.statusCode, 200);
    expect(response.data, isNotEmpty);
  });

  test('2 POST /Users/AuthenticateByName', () async {
    expect(accessToken, isNotEmpty);
    expect(userId, isNotEmpty);
  });

  test('3 GET /Users/{userId}/Views', () async {
    final views = await api.getViews();
    expect(views.items, isNotEmpty);
  });

  test('4 GET /Users/{userId}/Items browse', () async {
    final views = await api.getViews();
    final first = views.items.first;
    final page = await api.getItems(parentId: first.id, limit: 5);
    expect(page.items.length, lessThanOrEqualTo(5));
  });

  test('5 GET item detail with Chapters field', () async {
    final views = await api.getViews();
    final page = await api.getItems(parentId: views.items.first.id, limit: 1);
    if (page.items.isEmpty) return;
    final detail = await api.getItemDetail(
      page.items.first.id!,
      fields: 'Chapters,ProviderIds',
    );
    expect(detail.id, isNotNull);
  });

  test('6 GET /Items/{id}/PlaybackInfo', () async {
    final views = await api.getViews();
    final page = await api.getItems(parentId: views.items.first.id, limit: 1);
    if (page.items.isEmpty) return;
    final info = await api.getPlaybackInfo(page.items.first.id!);
    expect(info, isNotNull);
  });

  test('7 HEAD stream URL reachable', () async {
    final views = await api.getViews();
    final page = await api.getItems(parentId: views.items.first.id, limit: 1);
    if (page.items.isEmpty) return;
    final itemId = page.items.first.id!;
    final playback = await api.getPlaybackInfo(itemId);
    final source = playback.mediaSources?.firstOrNull;
    final url = EmbyApiService.buildStreamUrl(
      baseUrl: serverUrl,
      itemId: itemId,
      accessToken: accessToken,
      mediaSourceId: source?.id,
    );
    final head = await dio.head(url);
    expect(head.statusCode, anyOf(200, 206, 302));
  });

  test('8 POST playback reporting endpoints', () async {
    final views = await api.getViews();
    final page = await api.getItems(parentId: views.items.first.id, limit: 1);
    if (page.items.isEmpty) return;
    final itemId = page.items.first.id!;
    final playback = await api.getPlaybackInfo(itemId);
    final sourceId = playback.mediaSources?.firstOrNull?.id ?? itemId;

    expect(await api.reportPlaybackStart(itemId, sourceId), isTrue);
    expect(
      await api.reportPlaybackProgress(itemId, sourceId, positionTicks: 10000000),
      isTrue,
    );
    expect(
      await api.reportPlaybackStopped(itemId, sourceId, positionTicks: 10000000),
      isTrue,
    );
  });
}

extension _FirstOrNull<E> on List<E>? {
  E? get firstOrNull => this == null || this!.isEmpty ? null : this!.first;
}
