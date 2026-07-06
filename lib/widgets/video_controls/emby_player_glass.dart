import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:emby_player/widgets/app_icon.dart';

import '../../focus/focusable_wrapper.dart';
import '../../theme/emby_glass_theme.dart';

/// Glass tuned for controls over MPV / platform video surfaces.
LiquidGlassSettings embyPlayerGlassSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return embyChromeGlassSettings(context).copyWith(
    blur: isDark ? 26 : 20,
    thickness: 38,
    glassColor: isDark ? const Color(0x52FFFFFF) : const Color(0x66FFFFFF),
    ambientStrength: isDark ? 0.25 : 0.4,
    backerColor: const Color(0x73000000),
  );
}

const kEmbyPlayerControlBarHeight = 40.0;
const kEmbyPlayerScrubberBarHeight = 30.0;

/// Floating glass pill for player chrome (top title bar, bottom transport).
class EmbyPlayerGlassBar extends StatelessWidget {
  const EmbyPlayerGlassBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.margin,
    this.borderRadius = 22,
    this.minHeight,
    this.maxHeight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double? minHeight;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: GlassContainer(
        useOwnLayer: true,
        platformViewBackdrop: true,
        quality: embyChromeGlassQuality(),
        settings: embyPlayerGlassSettings(context),
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minHeight ?? 0,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (margin == null) return bar;
    return Padding(padding: margin!, child: bar);
  }
}

/// Circular glass transport button for mobile/desktop player.
class EmbyPlayerGlassIconButton extends StatelessWidget {
  const EmbyPlayerGlassIconButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.iconSize = 24,
    this.size = 52,
    this.color = Colors.white,
    this.focusNode,
    this.onKeyEvent,
    this.onFocusChange,
    this.tooltip,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;
  final double iconSize;
  final double size;
  final Color color;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKeyEvent;
  final ValueChanged<bool>? onFocusChange;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Plain icon buttons — the parent [EmbyPlayerGlassBar] supplies the glass surface.
    final button = IconButton(
      icon: AppIcon(
        icon,
        fill: 1,
        size: iconSize,
        color: enabled ? color : color.withValues(alpha: 0.35),
      ),
      onPressed: onPressed,
      iconSize: iconSize,
      tooltip: tooltip ?? semanticLabel,
      style: IconButton.styleFrom(
        minimumSize: Size(size, size),
        maximumSize: Size(size, size),
      ),
    );

    if (focusNode == null && onKeyEvent == null && onFocusChange == null) {
      return Semantics(label: semanticLabel, button: true, child: Tooltip(message: tooltip ?? semanticLabel, child: button));
    }

    return FocusableWrapper(
      focusNode: focusNode,
      onSelect: onPressed,
      onKeyEvent: onKeyEvent,
      onFocusChange: onFocusChange,
      borderRadius: size / 2,
      autoScroll: false,
      useBackgroundFocus: true,
      semanticLabel: semanticLabel,
      child: Semantics(
        label: semanticLabel,
        button: true,
        excludeSemantics: true,
        child: Tooltip(message: tooltip ?? semanticLabel, child: button),
      ),
    );
  }
}
