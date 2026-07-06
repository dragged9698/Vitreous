import 'package:flutter/material.dart';

import 'mono_tokens.dart';

/// Ambient mesh backdrop for the app shell — gives liquid glass something to refract.
class EmbyShellBackdrop extends StatefulWidget {
  const EmbyShellBackdrop({super.key});

  @override
  State<EmbyShellBackdrop> createState() => _EmbyShellBackdropState();
}

class _EmbyShellBackdropState extends State<EmbyShellBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = tokens(context);

    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) {
        final phase = _drift.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + phase * 0.15, -1),
                  end: Alignment(1 - phase * 0.1, 1),
                  colors: isDark
                      ? const [Color(0xFF07080C), Color(0xFF10131A), Color(0xFF0B0D14)]
                      : const [Color(0xFFF6F6FB), Color(0xFFE9EBF4), Color(0xFFF3F4FA)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -140 + phase * 30,
              left: -100 + phase * 20,
              child: _AmbientOrb(
                color: isDark ? const Color(0xFF4F5BD5) : const Color(0xFF7B9BFF),
                size: 380,
                opacity: isDark ? 0.28 : 0.22,
              ),
            ),
            Positioned(
              top: 180 - phase * 25,
              right: -120 + phase * 15,
              child: _AmbientOrb(
                color: isDark ? const Color(0xFF9B5DE5) : const Color(0xFFFF8BCB),
                size: 320,
                opacity: isDark ? 0.16 : 0.14,
              ),
            ),
            Positioned(
              bottom: -80 + phase * 20,
              left: 40 - phase * 10,
              child: _AmbientOrb(
                color: isDark ? const Color(0xFF2EC4B6) : const Color(0xFF5EDFCF),
                size: 360,
                opacity: isDark ? 0.14 : 0.12,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.4),
                  radius: 1.35,
                  colors: [
                    Colors.transparent,
                    (isDark ? Colors.black : t.text).withValues(alpha: isDark ? 0.42 : 0.06),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.03 : 0.35),
                    Colors.transparent,
                    (isDark ? Colors.black : t.text).withValues(alpha: isDark ? 0.25 : 0.03),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
