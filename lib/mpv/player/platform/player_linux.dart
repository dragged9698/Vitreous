import '../player_native.dart';
import '../video_rect_support.dart';

/// Linux MPV player — Flutter texture (SDR tonemap) or native embed (HDR passthrough).
class PlayerLinux extends PlayerNative with VideoRectSupport {
  @override
  int? get textureId => usesLinuxEmbed ? null : super.textureId;

  @override
  Future<void> setVideoRect({
    required int left,
    required int top,
    required int right,
    required int bottom,
    required double devicePixelRatio,
  }) async {
    await invoke('setVideoRect', {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'devicePixelRatio': devicePixelRatio,
    });
  }
}
