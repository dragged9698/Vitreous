import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'vitreous_glass_exception.dart';

/// Captures [RepaintBoundary] snapshots and feeds them to Vitreous glass shaders.
///
/// Impeller path: prefers synchronous [RenderRepaintBoundary.toImageSync] to keep
/// textures in GPU memory. Skia fallback uses async [toImage].
class RefractionController extends ChangeNotifier {
  RefractionController({this.pixelRatioOverride, this.maxCapturesPerSecond = 60});

  final GlobalKey repaintBoundaryKey = GlobalKey(debugLabel: 'vitreous_bg');

  final double? pixelRatioOverride;
  final int maxCapturesPerSecond;

  ui.Image? _snapshot;
  ui.Image? get snapshot => _snapshot;

  Size? _lastLogicalSize;
  Offset? _lastGlobalOrigin;
  bool _captureInFlight = false;
  int _captureCount = 0;
  int _uniformPushCount = 0;
  Duration? _lastCaptureDuration;
  Duration? _lastFrameTime;
  Object? _lastError;

  int get captureCount => _captureCount;
  int get uniformPushCount => _uniformPushCount;
  Duration? get lastCaptureDuration => _lastCaptureDuration;
  Duration? get lastFrameTime => _lastFrameTime;
  Object? get lastError => _lastError;

  bool get hasValidSnapshot => _snapshot != null;

  /// Whether Impeller's shader filter path is available (Vulkan/Metal).
  static bool get isImpeller => ui.ImageFilter.isShaderFilterSupported;

  void recordUniformPush() => _uniformPushCount++;

  void recordFrameTime(Duration frameTime) => _lastFrameTime = frameTime;

  /// Request a background capture if geometry changed or [force] is true.
  Future<void> captureIfNeeded(BuildContext context, {bool force = false}) async {
    final boundary = repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.hasSize) return;

    final box = boundary as RenderBox;
    final logicalSize = boundary.size;
    final globalOrigin = box.localToGlobal(Offset.zero);
    final dpr = pixelRatioOverride ?? View.of(context).devicePixelRatio;

    final geometryChanged = _lastLogicalSize != logicalSize || _lastGlobalOrigin != globalOrigin;

    if (!force && !geometryChanged && _snapshot != null) return;
    if (_captureInFlight) return;

    _captureInFlight = true;
    final sw = Stopwatch()..start();

    try {
      final ui.Image next;
      if (isImpeller) {
        next = boundary.toImageSync(pixelRatio: dpr);
      } else {
        next = await boundary.toImage(pixelRatio: dpr);
      }

      _snapshot?.dispose();
      _snapshot = next;
      _lastLogicalSize = logicalSize;
      _lastGlobalOrigin = globalOrigin;
      _captureCount++;
      _lastCaptureDuration = sw.elapsed;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _lastError = VitreousGlassException(
        'RepaintBoundary.toImage failed — check Impeller is enabled and the '
        'boundary has painted at least one frame.',
        cause: e,
      );
      FlutterError.reportError(FlutterErrorDetails(exception: _lastError!, stack: st));
    } finally {
      _captureInFlight = false;
    }
  }

  /// Schedule capture after the current frame completes (safe first-mount path).
  void scheduleCaptureAfterFrame(BuildContext context, {bool force = false}) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        unawaited(captureIfNeeded(context, force: force));
      }
    });
  }

  @override
  void dispose() {
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }
}
