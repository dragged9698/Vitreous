import 'package:flutter/material.dart';

import '../theme/emby_glass_theme.dart';

/// Shell backdrop anchor colors — keep hero bottom fade aligned with [EmbyShellBackdrop].
Color embyShellBackdropMidColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF10131A) : const Color(0xFFE9EBF4);
}

Color embyShellBackdropBottomColor(BuildContext context) {
  return embyFlatPageColor(context);
}

/// Fades hero artwork into the shell backdrop by masking image alpha at the bottom.
///
/// Shader mask is applied to the image layer only — not glass chrome — so Impeller
/// backdrop sampling stays intact.
class EmbyHeroImageBackdropMask extends StatelessWidget {
  const EmbyHeroImageBackdropMask({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  // Long multi-stop falloff — avoids a visible alpha cliff at the hero bottom edge.
  static const _fadeStops = <double>[0.0, 0.34, 0.58, 0.74, 0.86, 0.96, 1.0];
  static const _fadeColors = <Color>[
    Colors.white,
    Colors.white,
    Color(0xE6FFFFFF),
    Color(0x99FFFFFF),
    Color(0x4DFFFFFF),
    Color(0x14FFFFFF),
    Colors.transparent,
  ];

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _fadeColors,
        stops: _fadeStops,
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// Legibility scrims for Discover hero art. Bottom blending is handled by
/// EmbyHeroImageBackdropMask so the animated shell backdrop shows through.
class EmbyHeroFadeOverlay extends StatelessWidget {
  const EmbyHeroFadeOverlay({
    super.key,
    required this.width,
    this.blendToShellBackdrop = true,
  });

  final double width;
  final bool blendToShellBackdrop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      width: width,
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Colors.transparent],
                  stops: [0.0, 0.28],
                ),
              ),
            ),
            if (blendToShellBackdrop)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: isDark ? 0.12 : 0.07),
                      Colors.black.withValues(alpha: isDark ? 0.06 : 0.03),
                      Colors.transparent,
                    ],
                    // All scrim weight tapers out well before the hero bottom edge.
                    stops: const [0.4, 0.58, 0.72, 0.84],
                  ),
                ),
              )
            else ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, 0.55),
                    radius: 1.15,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: isDark ? 0.18 : 0.1),
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
                      Colors.transparent,
                      scaffoldColor.withValues(alpha: 0.55),
                      scaffoldColor.withValues(alpha: 0.92),
                      scaffoldColor,
                    ],
                    stops: const [0.45, 0.78, 0.94, 1.0],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
