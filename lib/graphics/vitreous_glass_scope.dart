import 'package:flutter/material.dart';

import 'refraction_controller.dart';
import 'vitreous_glass_panel.dart';

/// Hosts a [RepaintBoundary] backdrop for [VitreousGlassPanel] refraction.
///
/// Place behind chrome in a [Stack]:
/// ```dart
/// VitreousGlassScope(
///   controller: refractionController,
///   child: opaqueLibraryContent,
/// )
/// // ...
/// VitreousGlassPanel(
///   backgroundKey: refractionController.repaintBoundaryKey,
///   child: navChrome,
/// )
/// ```
class VitreousGlassScope extends StatelessWidget {
  const VitreousGlassScope({super.key, required this.controller, required this.child});

  final RefractionController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: controller.repaintBoundaryKey, child: child);
  }
}
