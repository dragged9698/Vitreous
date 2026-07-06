import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../focus/focusable_action_bar.dart';
import '../theme/emby_glass_theme.dart';

/// Frosted pill for **non-glass** chrome only (labels, metadata, play affordances).
///
/// Per `liquid_glass_widgets` composition rules, never wrap [GlassSegmentedControl],
/// [GlassIconButton], [GlassButton], or other refractive controls in this shell.
class EmbyGlassPill extends StatelessWidget {
  const EmbyGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.minHeight = 48,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(embyChromeCornerRadiusCollapsed),
      child: GlassContainer(
        useOwnLayer: true,
        quality: embyChromeGlassQuality(),
        settings: embyChromeGlassSettings(context),
        shape: LiquidRoundedSuperellipse(borderRadius: embyChromeCornerRadiusCollapsed),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// In-page toolbar: glass tab control on the left, glass action cluster on the right.
class EmbyGlassPageToolbar extends StatelessWidget {
  const EmbyGlassPageToolbar({
    super.key,
    required this.leading,
    this.center,
    this.actions,
    this.actionBarKey,
    this.onNavigateLeft,
    this.onNavigateDown,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4),
  });

  final Widget leading;
  final Widget? center;
  final List<FocusableAction>? actions;
  final GlobalKey<FocusableActionBarState>? actionBarKey;
  final VoidCallback? onNavigateLeft;
  final VoidCallback? onNavigateDown;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final actionWidgets = actions;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: leading),
          if (center != null) ...[const SizedBox(width: 12), center!],
          const Spacer(),
          if (actionWidgets != null && actionWidgets.isNotEmpty) ...[
            const SizedBox(width: 8),
            FocusableActionBar(
              key: actionBarKey,
              onNavigateLeft: onNavigateLeft,
              onNavigateDown: onNavigateDown,
              actions: actionWidgets,
            ),
          ],
        ],
      ),
    );
  }
}

/// Scrollable segmented control with persistent selection pill inside chrome glass.
class EmbyGlassSegmentedControl extends StatelessWidget {
  const EmbyGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
    this.height = 40,
    this.scrollable = true,
  });

  final List<GlassSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;
  final double height;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final muted = labelStyle.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88));

    final control = scrollable
        ? GlassSegmentedControl.scrollable(
            segments: segments,
            selectedIndex: selectedIndex.clamp(0, segments.length - 1),
            onSegmentSelected: onSegmentSelected,
            height: height,
            borderRadius: 18,
            padding: const EdgeInsets.all(3),
            useOwnLayer: true,
            quality: embyChromeGlassQuality(),
            settings: embyChromeGlassSettings(context),
            indicatorColor: embySegmentIndicatorColor(context),
            selectedTextStyle: labelStyle,
            unselectedTextStyle: muted,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            indicatorExpansion: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            indicatorPinchStrength: 0.35,
          )
        : GlassSegmentedControl(
            segments: segments,
            selectedIndex: selectedIndex.clamp(0, segments.length - 1),
            onSegmentSelected: onSegmentSelected,
            height: height,
            borderRadius: 18,
            padding: const EdgeInsets.all(3),
            useOwnLayer: true,
            quality: embyChromeGlassQuality(),
            settings: embyChromeGlassSettings(context),
            indicatorColor: embySegmentIndicatorColor(context),
            selectedTextStyle: labelStyle,
            unselectedTextStyle: muted,
            labelPadding: const EdgeInsets.symmetric(horizontal: 14),
            indicatorExpansion: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            indicatorPinchStrength: 0.35,
          );

    return embyGlassSegmentScope(context, child: control);
  }
}

/// Metadata chip with glass styling (detail heroes, Live TV, etc.).
class EmbyGlassMetadataChip extends StatelessWidget {
  const EmbyGlassMetadataChip({super.key, required this.label, this.icon, this.leading});

  final String label;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final text = Text(
      label,
      style: TextStyle(color: onSurface, fontSize: 13, fontWeight: FontWeight.w600),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: GlassContainer(
        useOwnLayer: true,
        quality: embyChromeGlassQuality(),
        settings: embyChromeGlassSettings(context).copyWith(glassColor: onSurface.withValues(alpha: 0.12)),
        shape: const LiquidRoundedSuperellipse(borderRadius: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: leading != null || icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) leading! else Icon(icon, size: 16, color: onSurface),
                    const SizedBox(width: 4),
                    text,
                  ],
                )
              : text,
        ),
      ),
    );
  }
}

/// Centered empty/error state inside a glass card.
class EmbyGlassStateCard extends StatelessWidget {
  const EmbyGlassStateCard({super.key, required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassGroupedSection(
          margin: const EdgeInsets.all(24),
          useOwnLayer: true,
          quality: embyChromeGlassQuality(),
          settings: embyChromeGlassSettings(context),
          children: [
            GlassListTile(
              leading: Icon(icon, size: 32, color: theme.colorScheme.onSurface),
              title: Text(message, textAlign: TextAlign.center),
              subtitle: actionLabel != null && onAction != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GlassButton.custom(
                        onTap: onAction!,
                        width: double.infinity,
                        height: 44,
                        child: Text(actionLabel!),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact stats strip (channel count, filter state, etc.).
class EmbyGlassInfoStrip extends StatelessWidget {
  const EmbyGlassInfoStrip({super.key, required this.children, this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8)});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: EmbyGlassPill(
        minHeight: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 1,
                    height: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
