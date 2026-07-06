import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'refraction_controller.dart';
import 'vitreous_glass_shader.dart';

/// Paints Vitreous liquid glass via [CustomPainter] + fragment shader.
class VitreousGlassPainter extends CustomPainter {
  VitreousGlassPainter({
    required this.shader,
    required this.vitreousShader,
    required this.controller,
    required this.glassTint,
    required this.refractionStrength,
    required this.fresnelPower,
    required this.backdropLuma,
    required this.blurRadius,
    required this.devicePixelRatio,
    required this.bgGlobalOrigin,
    this.onUniformsBound,
  }) : super(repaint: controller);

  final ui.FragmentShader shader;
  final VitreousGlassShader vitreousShader;
  final RefractionController controller;
  final Color glassTint;
  final double refractionStrength;
  final double fresnelPower;
  final double backdropLuma;
  final double blurRadius;
  final double devicePixelRatio;
  final Offset bgGlobalOrigin;
  final VoidCallback? onUniformsBound;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = canvas.getTransform();
    final scale = Offset(matrix[0], matrix[5]);
    final physicalOrigin = Offset(matrix[12], matrix[13]);

    final panelGlobalLogical = Offset(physicalOrigin.dx / scale.dx, physicalOrigin.dy / scale.dy);
    final bgRelative = panelGlobalLogical - bgGlobalOrigin;

    final snapshot = controller.snapshot;
    final bgSize = snapshot != null
        ? Size(snapshot.width / devicePixelRatio, snapshot.height / devicePixelRatio)
        : const Size(1, 1);

    final uniforms = VitreousGlassUniforms(
      panelSize: size,
      physicalOrigin: physicalOrigin,
      scale: scale,
      glassTint: glassTint,
      refractionStrength: refractionStrength,
      fresnelPower: fresnelPower,
      backdropLuma: backdropLuma,
      blurRadius: blurRadius,
      bgRelativeOrigin: bgRelative,
      bgSize: bgSize,
    );

    vitreousShader.bind(shader: shader, uniforms: uniforms, background: snapshot);
    onUniformsBound?.call();
    controller.recordUniformPush();

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant VitreousGlassPainter oldDelegate) {
    return oldDelegate.shader != shader ||
        oldDelegate.glassTint != glassTint ||
        oldDelegate.refractionStrength != refractionStrength ||
        oldDelegate.fresnelPower != fresnelPower ||
        oldDelegate.backdropLuma != backdropLuma ||
        oldDelegate.blurRadius != blurRadius ||
        oldDelegate.bgGlobalOrigin != bgGlobalOrigin ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.controller.snapshot != controller.snapshot;
  }
}
