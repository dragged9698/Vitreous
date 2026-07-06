import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'refraction_controller.dart';
import 'vitreous_glass_surface.dart';

/// Liquid glass panel: RepaintBoundary snapshot → fragment shader refraction.
///
/// Wrap chrome only — keep media grids and posters opaque per Vitreous layering rules.
class VitreousGlassPanel extends StatelessWidget {
  const VitreousGlassPanel({
    super.key,
    required this.child,
    required this.backgroundKey,
    required this.controller,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.glassTint,
    this.refractionStrength = 1.0,
    this.fresnelPower = 2.4,
    this.blurRadius = 6.0,
    this.padding = EdgeInsets.zero,
    this.showDebugStats = false,
  });

  final Widget child;
  final GlobalKey backgroundKey;
  final BorderRadius borderRadius;
  final Color? glassTint;
  final double refractionStrength;
  final double fresnelPower;
  final double blurRadius;
  final EdgeInsets padding;
  final RefractionController controller;
  final bool showDebugStats;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
              fit: StackFit.passthrough,
              children: [
                VitreousGlassSurface(
                  controller: activeController,
                  backgroundKey: backgroundKey,
                  borderRadius: borderRadius,
                  glassTint: glassTint,
                  refractionStrength: refractionStrength,
                  fresnelPower: fresnelPower,
                  blurRadius: blurRadius,
                  showDebugStats: showDebugStats,
                ),
                Padding(padding: padding, child: child),
              ],
            )
            .animate()
            .fadeIn(duration: 220.ms, curve: Curves.easeOutCubic)
            .scale(
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              duration: 280.ms,
              curve: Curves.easeOutBack,
            );
      },
    );
  }
}
