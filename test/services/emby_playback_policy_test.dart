import 'package:emby_player/services/emby_playback_policy.dart';
import 'package:emby_player/services/emby_playback_urls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('embySourceNeedsTranscode', () {
    test('returns true only when Emby disables direct play or stream', () {
      expect(embySourceNeedsTranscode({'SupportsDirectPlay': false}), isTrue);
      expect(embySourceNeedsTranscode({'SupportsDirectStream': false}), isTrue);
    });

    test('returns false for RequiresOpening symlink mounts when direct stream is allowed', () {
      expect(
        embySourceNeedsTranscode({
          'SupportsDirectPlay': true,
          'SupportsDirectStream': true,
          'RequiresOpening': true,
          'Path': '/mnt/decypharr/library/movie.mkv',
        }),
        isFalse,
      );
    });
  });

  group('embySourceNeedsLiveStreamOpen', () {
    test('returns true for RequiresOpening and OpenToken', () {
      expect(embySourceNeedsLiveStreamOpen({'RequiresOpening': true}), isTrue);
      expect(embySourceNeedsLiveStreamOpen({'OpenToken': 'abc'}), isTrue);
    });

    test('returns true for decypharr paths', () {
      expect(
        embySourceNeedsLiveStreamOpen({
          'Path': '/data/decypharr/movies/foo.mkv',
        }),
        isTrue,
      );
    });
  });

  group('embySourcePrefersStaticStream', () {
    test('never uses static reads for network playback', () {
      expect(
        embySourcePrefersStaticStream({
          'RequiresOpening': false,
          'IsRemote': false,
          'Size': 4_000_000_000,
        }),
        isFalse,
      );
    });
  });

  group('sanitizeMediaBrowserDirectStreamUrl', () {
    test('strips Static for progressive streaming', () {
      const url = 'https://emby.example/Videos/abc/stream?Static=true&api_key=tok';
      expect(
        sanitizeMediaBrowserDirectStreamUrl(url, staticStream: false),
        'https://emby.example/Videos/abc/stream?api_key=tok',
      );
    });

    test('adds Static when byte-range read is safe', () {
      const url = 'https://emby.example/Videos/abc/stream?api_key=tok';
      expect(
        sanitizeMediaBrowserDirectStreamUrl(url, staticStream: true),
        'https://emby.example/Videos/abc/stream?api_key=tok&Static=true',
      );
    });
  });

  group('buildEmbyDirectStreamUrl', () {
    test('uses container extension for progressive streams', () {
      final url = buildEmbyDirectStreamUrl(
        baseUrl: 'https://emby.example',
        accessToken: 'tok',
        deviceId: 'dev',
        itemId: 'abc',
        container: 'mkv',
        staticStream: false,
      );
      expect(url, contains('/Videos/abc/stream.mkv?'));
      expect(url, isNot(contains('Static=true')));
    });
  });

  group('embyUrlLooksLikeHlsTranscode', () {
    test('detects master playlists mislabeled as direct stream', () {
      expect(
        embyUrlLooksLikeHlsTranscode(
          '/videos/1335211/master.m3u8?VideoBitrate=7616000&TranscodeReasons=ContainerBitrateExceedsLimit',
        ),
        isTrue,
      );
      expect(
        embyIsProgressiveDirectStreamUrl('/Videos/1335211/stream.mkv?Static=true'),
        isTrue,
      );
    });
  });

  group('embyBundleSupportsDirectPlayback', () {
    test('returns true when item metadata allows direct play and stream', () {
      expect(
        embyBundleSupportsDirectPlayback({
          'SupportsDirectPlay': true,
          'SupportsDirectStream': true,
        }),
        isTrue,
      );
    });
  });

  group('embyWithTranscodeStartTimeTicks', () {
    test('injects StartTimeTicks when absent', () {
      const url = '/Videos/item-1/master.m3u8?MediaSourceId=src-1&PlaySessionId=s1';
      expect(
        embyWithTranscodeStartTimeTicks(url, 140000000),
        '/Videos/item-1/master.m3u8?MediaSourceId=src-1&PlaySessionId=s1&StartTimeTicks=140000000',
      );
    });

    test('overwrites stale StartTimeTicks from server', () {
      const url = '/Videos/item-1/master.m3u8?StartTimeTicks=61310000&PlaySessionId=s1';
      expect(
        embyWithTranscodeStartTimeTicks(url, 140000000),
        '/Videos/item-1/master.m3u8?StartTimeTicks=140000000&PlaySessionId=s1',
      );
    });

    test('leaves url unchanged when ticks are null or zero', () {
      const url = '/Videos/item-1/master.m3u8';
      expect(embyWithTranscodeStartTimeTicks(url, null), url);
      expect(embyWithTranscodeStartTimeTicks(url, 0), url);
    });
  });

  group('embyPickHlsTranscodeUrl', () {
    test('prefers transcodingUrl but falls back to mislabeled directStreamUrl', () {
      expect(
        embyPickHlsTranscodeUrl(
          '/videos/1/master.m3u8?TranscodeReasons=ContainerBitrateExceedsLimit',
          null,
        ),
        isNotNull,
      );
      expect(
        embyPickHlsTranscodeUrl(
          null,
          '/videos/1/master.m3u8?VideoBitrate=7616000',
        ),
        isNotNull,
      );
      expect(embyPickHlsTranscodeUrl(null, '/videos/1/original.mkv'), isNull);
    });
  });
}
