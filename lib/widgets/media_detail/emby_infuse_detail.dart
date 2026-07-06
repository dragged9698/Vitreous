import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../media/media_item.dart';
import '../../theme/emby_glass_theme.dart';
import '../app_icon.dart';
import '../collapsible_text.dart';
import '../emby_glass_chrome.dart';

/// Infuse-style detail page chrome: hero metadata, glass actions, section headers.
abstract final class EmbyInfuseDetailLayout {
  static const double heroHeightFraction = 0.62;
  static const double playPillHeight = 52;
  static const double utilityIconSize = 40;
  static const double episodeThumbWidth = 200;
  static const double episodeThumbAspect = 16 / 9;
}

/// Glass section title (Season N, Cast and Crew, etc.).
class EmbyInfuseSectionHeader extends StatelessWidget {
  const EmbyInfuseSectionHeader({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: EmbyGlassPill(
        minHeight: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              AppIcon(icon!, fill: 1, size: 18, color: theme.colorScheme.onSurface),
              const SizedBox(width: 8),
            ],
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

/// Inline metadata row with middot separators (Infuse style).
class EmbyInfuseMetadataRow extends StatelessWidget {
  const EmbyInfuseMetadataRow({super.key, required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
      fontWeight: FontWeight.w500,
      height: 1.3,
    );
    return Text(parts.join('  ·  '), style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
  }
}

/// Primary resume / play affordance with optional progress strip.
class EmbyInfusePlayPill extends StatelessWidget {
  const EmbyInfusePlayPill({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.progress,
    this.focusNode,
    this.showFocus = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double? progress;
  final FocusNode? focusNode;
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    Widget pill = EmbyGlassPill(
      minHeight: EmbyInfuseDetailLayout.playPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, fill: 1, size: 22, color: onSurface),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (progress != null && progress! > 0 && progress! < 1)
            Positioned(
              left: 12,
              right: 12,
              bottom: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: onSurface.withValues(alpha: 0.12),
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );

    if (showFocus) {
      pill = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(embyChromeCornerRadiusCollapsed),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: pill,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(embyChromeCornerRadiusCollapsed),
        child: pill,
      ),
    );
  }
}

/// Secondary trailer / extras pill.
class EmbyInfuseSecondaryPill extends StatelessWidget {
  const EmbyInfuseSecondaryPill({super.key, required this.label, required this.onPressed, this.showFocus = false});

  final String label;
  final VoidCallback onPressed;
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill = EmbyGlassPill(
      minHeight: EmbyInfuseDetailLayout.playPillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      child: Center(
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ),
    );

    if (showFocus) {
      pill = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(embyChromeCornerRadiusCollapsed),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: pill,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(embyChromeCornerRadiusCollapsed),
        child: pill,
      ),
    );
  }
}

/// Utility icon — bare [GlassIconButton], never nested in another glass shell.
class EmbyInfuseUtilityButton extends StatelessWidget {
  const EmbyInfuseUtilityButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.showFocus = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isActive;
  final Color? activeColor;
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final color = isActive ? (activeColor ?? Theme.of(context).colorScheme.primary) : onSurface;

    Widget button = Tooltip(
      message: tooltip,
      child: GlassIconButton(
        icon: AppIcon(icon, fill: 1, size: 20, color: color),
        onPressed: onPressed,
        size: EmbyInfuseDetailLayout.utilityIconSize,
        glowColor: isActive ? color.withValues(alpha: 0.35) : null,
      ),
    );

    if (showFocus) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: button,
      );
    }

    return button;
  }
}

/// Hero content column: title, metadata, synopsis, actions.
class EmbyInfuseDetailHero extends StatelessWidget {
  const EmbyInfuseDetailHero({
    super.key,
    required this.metadata,
    required this.titleWidget,
    this.subtitle,
    required this.metadataParts,
    this.genreLine,
    required this.ratingRow,
    this.summary,
    required this.actions,
    this.maxSummaryLines = 4,
  });

  final MediaItem metadata;
  final Widget titleWidget;
  final String? subtitle;
  final List<String> metadataParts;
  final String? genreLine;
  final Widget ratingRow;
  final String? summary;
  final Widget actions;
  final int maxSummaryLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.55,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleWidget,
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.92),
              letterSpacing: -0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (metadataParts.isNotEmpty) ...[const SizedBox(height: 10), EmbyInfuseMetadataRow(parts: metadataParts)],
        if (genreLine != null && genreLine!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            genreLine!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (ratingRow is! SizedBox) ...[const SizedBox(height: 10), ratingRow],
        if (summary != null && summary!.isNotEmpty) ...[
          const SizedBox(height: 14),
          CollapsibleText(text: summary!, maxLines: maxSummaryLines, style: summaryStyle),
        ],
        const SizedBox(height: 18),
        actions,
      ],
    );
  }
}

/// Opaque episode thumbnail for horizontal season rail (no glass on media).
class EmbyInfuseEpisodeThumb extends StatelessWidget {
  const EmbyInfuseEpisodeThumb({
    super.key,
    required this.title,
    required this.thumbnail,
    required this.onTap,
    this.isUnwatched = false,
    this.width = EmbyInfuseDetailLayout.episodeThumbWidth,
  });

  final String title;
  final Widget thumbnail;
  final VoidCallback onTap;
  final bool isUnwatched;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbHeight = width / EmbyInfuseDetailLayout.episodeThumbAspect;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: width, height: thumbHeight, child: thumbnail),
                  ),
                  if (isUnwatched)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: CustomPaint(
                        size: const Size(28, 28),
                        painter: _UnwatchedCornerPainter(color: theme.colorScheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnwatchedCornerPainter extends CustomPainter {
  _UnwatchedCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(size.width * 0.45, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _UnwatchedCornerPainter oldDelegate) => oldDelegate.color != color;
}

/// Glass back affordance for detail hero overlay.
class EmbyInfuseBackButton extends StatelessWidget {
  const EmbyInfuseBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: GlassIconButton(
        icon: AppIcon(Symbols.arrow_back_rounded, fill: 1, size: 22, color: Theme.of(context).colorScheme.onSurface),
        onPressed: onPressed,
        size: 40,
      ),
    );
  }
}
