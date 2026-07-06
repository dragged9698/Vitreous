import 'dart:convert';

import 'package:emby_player/connection/connection.dart';
import 'package:emby_player/media/media_backend.dart';
import 'package:emby_player/media/media_kind.dart';
import 'package:emby_player/media/media_item.dart';
import 'package:emby_player/services/emby_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

EmbyConnection _conn() => EmbyConnection(
  id: 'srv-1/user-1',
  baseUrl: 'http://127.0.0.1:8096/emby',
  serverName: 'Emby',
  serverMachineId: 'srv-1',
  userId: 'user-1',
  userName: 'user',
  accessToken: 'tok-abc',
  deviceId: 'device-1',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  group('EmbyClient watch state URLs', () {
    test('rate uses /Users/{userId}/Items/{itemId}/Rating with JSON Likes body', () async {
      final captured = <http.Request>[];
      final scoped = EmbyClient.forTesting(
        connection: _conn(),
        httpClient: MockClient((request) async {
          captured.add(request);
          return http.Response('{}', 200, headers: {'content-type': 'application/json'});
        }),
      );
      addTearDown(scoped.close);

      final item = MediaItem(
        id: 'folder/item #1?x',
        backend: MediaBackend.emby,
        kind: MediaKind.movie,
        serverId: 'srv-1',
      );

      await scoped.rate(item, 7);
      await scoped.rate(item, 3);
      await scoped.rate(item, -1);

      final paths = captured.map((r) => r.url.path).toList();
      expect(
        paths,
        everyElement('/emby/Users/user-1/Items/folder%2Fitem%20%231%3Fx/Rating'),
      );
      expect(captured, hasLength(3));

      final likeBody = jsonDecode(captured[0].body) as Map<String, dynamic>;
      expect(likeBody['Likes'], isTrue);

      final dislikeBody = jsonDecode(captured[1].body) as Map<String, dynamic>;
      expect(dislikeBody['Likes'], isFalse);

      expect(captured[2].method, 'DELETE');
      expect(captured[2].body, isEmpty);
    });
  });
}
