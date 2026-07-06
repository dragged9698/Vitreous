import 'dart:convert';

import 'package:emby_player/connection/connection.dart';
import 'package:emby_player/media/media_backend.dart';
import 'package:emby_player/media/media_kind.dart';
import 'package:emby_player/media/media_item.dart';
import 'package:emby_player/models/transcode_quality_preset.dart';
import 'package:emby_player/services/emby_client.dart';
import 'package:emby_player/services/playback_initialization_types.dart';
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
  test('getPlaybackInitialization overwrites stale StartTimeTicks on transcode URL', () async {
    final scoped = EmbyClient.forTesting(
      connection: _conn(),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/Users/user-1/Items/item-1')) {
          return http.Response(
            jsonEncode({
              'Id': 'item-1',
              'Type': 'Movie',
              'Name': 'Movie',
              'MediaSources': [
                {
                  'Id': 'src-1',
                  'Container': 'mkv',
                  'SupportsDirectPlay': true,
                  'SupportsDirectStream': true,
                  'MediaStreams': [],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/Items/item-1/PlaybackInfo')) {
          return http.Response(
            jsonEncode({
              'PlaySessionId': 'play-session-1',
              'MediaSources': [
                {
                  'Id': 'src-1',
                  'TranscodingUrl':
                      '/Videos/item-1/master.m3u8?MediaSourceId=src-1&PlaySessionId=play-session-1&StartTimeTicks=61310000',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(scoped.close);

    final result = await scoped.getPlaybackInitialization(
      PlaybackInitializationOptions(
        metadata: MediaItem(
          id: 'item-1',
          backend: MediaBackend.emby,
          kind: MediaKind.movie,
          serverId: 'srv-1',
          viewOffsetMs: 14000,
        ),
        selectedMediaIndex: 0,
        qualityPreset: TranscodeQualityPreset.p480_1_5mbps,
      ),
    );

    expect(result.isTranscoding, isTrue);
    expect(result.playMethod, 'Transcode');
    final uri = Uri.parse(result.videoUrl!);
    expect(uri.queryParameters['StartTimeTicks'], '140000000');
    expect(uri.queryParameters['PlaySessionId'], 'play-session-1');
    expect(uri.queryParameters['api_key'], 'tok-abc');
  });
}
