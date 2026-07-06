import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../clickable_cursor.dart';
import '../app_icon.dart';
import '../emby_glass_chrome.dart';

/// Shared layout tokens for Live TV surfaces.
abstract final class EmbyLiveTvLayout {
  static const double guideCornerRadius = 16;
  static const double guideRowHeight = 56;
  static const double guideSlotWidth = 168;
  static const double guideChannelWidth = 116;
  static const double guideTimeHeaderHeight = 34;
  static const double programBlockRadius = 10;
  static const double programBlockInsetV = 4;
  static const double programBlockGap = 3;
}

/// Compact metadata shown between toolbar tabs and actions (channel count, filters).
class EmbyLiveTvToolbarMeta extends StatelessWidget {
  const EmbyLiveTvToolbarMeta({super.key, required this.icon, required this.label, this.accent});

  final IconData icon;
  final String label;
  final Widget? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return EmbyGlassPill(
      minHeight: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 16, color: onSurface.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
          if (accent != null) ...[const SizedBox(width: 8), accent!],
        ],
      ),
    );
  }
}

/// Glass section title for What's On / Recordings hub rows.
class EmbyLiveTvSectionTitle extends StatelessWidget {
  const EmbyLiveTvSectionTitle({super.key, required this.title, this.icon = Symbols.live_tv_rounded});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: EmbyGlassPill(
        minHeight: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, fill: 1, size: 18, color: theme.colorScheme.onSurface),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opaque rounded frame for the EPG grid (content stays opaque per glass README).
class EmbyLiveTvGuideFrame extends StatelessWidget {
  const EmbyLiveTvGuideFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final fill = theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(EmbyLiveTvLayout.guideCornerRadius),
          color: fill,
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(EmbyLiveTvLayout.guideCornerRadius), child: child),
      ),
    );
  }
}

/// Centered floating time navigator pill for the guide.
class EmbyLiveTvTimeNav extends StatelessWidget {
  const EmbyLiveTvTimeNav({
    super.key,
    required this.dayLabel,
    required this.timeLabel,
    required this.dayPickerKey,
    required this.onPrevious,
    required this.onNext,
    required this.onDayTap,
    required this.focusWrap,
  });

  final String dayLabel;
  final String timeLabel;
  final GlobalKey dayPickerKey;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDayTap;
  final Widget Function({required Widget child, required int index}) focusWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: EmbyGlassPill(
            minHeight: 40,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            child: Row(
              children: [
                focusWrap(
                  index: 0,
                  child: IconButton(
                    icon: const AppIcon(Symbols.chevron_left_rounded),
                    onPressed: onPrevious,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      focusWrap(
                        index: 1,
                        child: ClickableCursor(
                          child: GestureDetector(
                            key: dayPickerKey,
                            onTap: onDayTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dayLabel,
                                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  AppIcon(
                                    Symbols.arrow_drop_down_rounded,
                                    size: 20,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 18,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                      ),
                      Text(
                        timeLabel,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                focusWrap(
                  index: 2,
                  child: IconButton(
                    icon: const AppIcon(Symbols.chevron_right_rounded),
                    onPressed: onNext,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
