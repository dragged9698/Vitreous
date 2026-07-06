import 'package:emby_player/services/emby_playback_debug.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('embyMediaSourceDebugFields summarizes flags', () {
    final fields = embyMediaSourceDebugFields({
      'SupportsDirectStream': true,
      'RequiresOpening': true,
      'Path': '/mnt/decypharr/movie.mkv',
      'DirectStreamUrl': 'https://emby.test/Videos/x/stream?Static=true',
    });
    expect(fields['supportsDirectStream'], isTrue);
    expect(fields['requiresOpening'], isTrue);
    expect(fields['path'], '/mnt/decypharr/movie.mkv');
  });
}
