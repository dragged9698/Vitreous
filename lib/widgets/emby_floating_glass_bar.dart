import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Floating inset padding for mobile [GlassTabBar] — the bar supplies its own glass.
class EmbyFloatingGlassBar extends StatelessWidget {
  const EmbyFloatingGlassBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
          padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 10),
          child: child,
        )
        .animate()
        .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOutBack);
  }
}
