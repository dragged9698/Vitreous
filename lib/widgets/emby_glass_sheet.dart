import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/emby_glass_theme.dart';

/// Glass chrome wrapper for overlay sheet surfaces.
class EmbyGlassSheetChrome extends StatelessWidget {
  const EmbyGlassSheetChrome({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
          borderRadius: borderRadius,
          child: GlassContainer(
            useOwnLayer: true,
            quality: embyChromeGlassQuality(),
            settings: embyChromeGlassSettings(context),
            shape: LiquidRoundedSuperellipse(borderRadius: borderRadius.topLeft.x),
            child: Material(color: Colors.transparent, child: child),
          ),
        )
        .animate()
        .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.04, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
  }
}
