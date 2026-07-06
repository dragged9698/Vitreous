import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'graphics_debug_overlay.dart';
import 'refraction_controller.dart';
import 'vitreous_glass_painter.dart';
import 'vitreous_glass_shader.dart';

/// Shader-only glass layer — no child chrome. Use inside a [Stack] behind opaque controls.
class VitreousGlassSurface extends StatefulWidget {
  const VitreousGlassSurface({
    super.key,
    required this.controller,
    required this.backgroundKey,
    this.borderRadius = BorderRadius.zero,
    this.glassTint,
    this.refractionStrength = 1.0,
    this.fresnelPower = 2.4,
    this.blurRadius = 6.0,
    this.showDebugStats = false,
  });

  final RefractionController controller;
  final GlobalKey backgroundKey;
  final BorderRadius borderRadius;
  final Color? glassTint;
  final double refractionStrength;
  final double fresnelPower;
  final double blurRadius;
  final bool showDebugStats;

  @override
  State<VitreousGlassSurface> createState() => _VitreousGlassSurfaceState();
}

class _VitreousGlassSurfaceState extends State<VitreousGlassSurface> with SingleTickerProviderStateMixin {
  VitreousGlassShader? _shaderLib;
  ui.FragmentShader? _shader;
  Object? _initError;
  Ticker? _ticker;
  int _frameCount = 0;
  Duration _lastFrame = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    unawaited(_initShader());
  }

  Future<void> _initShader() async {
    try {
      final lib = await VitreousGlassShader.warmUp();
      if (!mounted) return;
      setState(() {
        _shaderLib = lib;
        _shader = lib.createFragmentShader();
        _initError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = e);
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (_lastFrame != Duration.zero) {
      widget.controller.recordFrameTime(now - _lastFrame);
    }
    _lastFrame = now;
    _frameCount++;
    widget.controller.scheduleCaptureAfterFrame(context);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shader == null || _shaderLib == null) {
      if (_initError != null && kDebugMode) {
        return ColoredBox(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.12));
      }
      return const SizedBox.expand();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = widget.glassTint ?? (isDark ? const Color(0x28FFFFFF) : const Color(0x38FFFFFF));
    final backdropLuma = isDark ? 0.15 : 0.85;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final boundary = widget.backgroundKey.currentContext?.findRenderObject() as RenderBox?;
    final bgOrigin = boundary?.localToGlobal(Offset.zero) ?? Offset.zero;

    Widget layer = RepaintBoundary(
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: CustomPaint(
          painter: VitreousGlassPainter(
            shader: _shader!,
            vitreousShader: _shaderLib!,
            controller: widget.controller,
            glassTint: tint,
            refractionStrength: widget.refractionStrength,
            fresnelPower: widget.fresnelPower,
            backdropLuma: backdropLuma,
            blurRadius: widget.blurRadius,
            devicePixelRatio: dpr,
            bgGlobalOrigin: bgOrigin,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );

    if (widget.showDebugStats) {
      layer = Stack(
        children: [
          layer,
          Positioned(
            left: 4,
            bottom: 4,
            child: GraphicsDebugOverlay(
              controller: widget.controller,
              frameCount: _frameCount,
              impeller: VitreousGlassShader.isSupported,
              initError: _initError,
            ),
          ),
        ],
      );
    }

    return layer;
  }
}
