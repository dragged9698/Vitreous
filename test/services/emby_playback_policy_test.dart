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

  group('embySourcePrefersStaticStream', () {
    test('returns false for virtual mounts that require server-side open', () {
      expect(
        embySourcePrefersStaticStream({
          'RequiresOpening': true,
          'Size': 4_000_000_000,
        }),
        isFalse,
      );
      expect(
        embySourcePrefersStaticStream({
          'IsRemote': true,
          'Size': 4_000_000_000,
        }),
        isFalse,
      );
      expect(embySourcePrefersStaticStream({'Size': 0}), isFalse);
    });

    test('returns true for normal local files with known size', () {
      expect(
        embySourcePrefersStaticStream({
          'RequiresOpening': false,
          'IsRemote': false,
          'Size': 4_000_000_000,
        }),
        isTrue,
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
}
