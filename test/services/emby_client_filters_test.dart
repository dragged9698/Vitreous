import 'dart:convert';

import 'package:emby_player/connection/connection.dart';
import 'package:emby_player/media/media_kind.dart';
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
  accessToken: 'token-1',
  deviceId: 'device-1',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  test('fetchLibraryFiltersWithValues uses /Genres items-by-name, not media rows', () async {
    final captured = <Uri>[];
    final scoped = EmbyClient.forTesting(
      connection: _conn(),
      httpClient: MockClient((req) async {
        captured.add(req.url);
        if (req.url.path.endsWith('/Items/Filters')) {
          return http.Response(
            jsonEncode({
              'Genres': ['Wrong Show Title'],
              'Tags': ['holiday'],
              'OfficialRatings': <String>[],
              'Years': <int>[],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (req.url.path.endsWith('/Genres')) {
          return http.Response(
            jsonEncode({
              'Items': [
                {'Name': 'Action', 'Id': 'genre-action', 'Type': 'Genre'},
                {'Name': 'Appraiser Is A Worthless Class', 'Id': 'series-1', 'Type': 'Series'},
                {'Name': 'Drama', 'Id': 'genre-drama', 'Type': 'Genre'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'Items': const []}), 200, headers: {'content-type': 'application/json'});
      }),
    );
    addTearDown(scoped.close);

    final result = await scoped.fetchLibraryFiltersWithValues('lib-1', libraryKind: MediaKind.show);

    final genresRequest = captured.firstWhere((uri) => uri.path.endsWith('/Genres'));
    expect(genresRequest.queryParameters.containsKey('MediaTypes'), isFalse);
    expect(result.filters.map((filter) => filter.filter), ['unwatched', 'genre', 'tag']);
    expect(result.cachedValues['genre']!.map((value) => value.key), ['Action', 'Drama']);
    expect(result.cachedValues['tag']!.map((value) => value.key), ['holiday']);
  });
}
