import 'package:flutter/material.dart';

import 'refraction_controller.dart';
import 'vitreous_glass_scope.dart';
import 'vitreous_glass_shader.dart';
import 'vitreous_refraction_scope.dart';

/// App-level host: captures opaque content for Vitreous refraction chrome.
class VitreousGlassHost extends StatelessWidget {
  const VitreousGlassHost({super.key, required this.controller, required this.child});

  final RefractionController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!VitreousGlassShader.isSupported) return child;
    return VitreousRefractionScope(
      controller: controller,
      child: VitreousGlassScope(controller: controller, child: child),
    );
  }
}
