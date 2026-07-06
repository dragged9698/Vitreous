import 'package:flutter/material.dart';

import 'refraction_controller.dart';
import 'vitreous_glass_shader.dart';

/// Provides a shared [RefractionController] for [VitreousGlassSurface] chrome.
class VitreousRefractionScope extends InheritedWidget {
  const VitreousRefractionScope({super.key, required this.controller, required super.child});

  final RefractionController controller;

  static RefractionController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<VitreousRefractionScope>()?.controller;
  }

  static RefractionController of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'VitreousRefractionScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(VitreousRefractionScope oldWidget) => controller != oldWidget.controller;
}

/// Whether Vitreous refraction should render on this platform.
bool vitreousGlassEnabled() => VitreousGlassShader.isSupported;
