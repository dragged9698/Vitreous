import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../i18n/strings.g.dart';
import '../navigation/navigation_tabs.dart';
import '../theme/emby_glass_theme.dart';
import 'app_icon.dart';

/// Infuse-style top navigation: search on the far left, text tabs in the center
/// with an animated liquid-glass pill on the selected segment, fullscreen on
/// the far right — all inside one row.
class EmbyInfuseSegmentedNav extends StatelessWidget {
  const EmbyInfuseSegmentedNav({
    super.key,
    required this.visibleTabs,
    required this.selectedTab,
    required this.onTabSelected,
    this.onLibrariesSegmentHover,
    this.onLibrariesSegmentSelected,
    this.isOfflineMode = false,
    this.isReconnecting = false,
    this.onReconnect,
    this.height = 40,
    this.showFullscreenToggle = false,
    this.isFullscreen = false,
    this.onFullscreenToggle,
    this.searchFocusNode,
    this.fullscreenFocusNode,
    this.onNavigateToContent,
  });

  final List<NavigationTab> visibleTabs;
  final NavigationTabId selectedTab;
  final ValueChanged<NavigationTabId> onTabSelected;
  final VoidCallback? onLibrariesSegmentHover;
  final VoidCallback? onLibrariesSegmentSelected;
  final bool isOfflineMode;
  final bool isReconnecting;
  final VoidCallback? onReconnect;
  final double height;
  final bool showFullscreenToggle;
  final bool isFullscreen;
  final VoidCallback? onFullscreenToggle;
  final FocusNode? searchFocusNode;
  final FocusNode? fullscreenFocusNode;
  final VoidCallback? onNavigateToContent;

  List<NavigationTab> get _centerTabs =>
      visibleTabs.where((tab) => tab.id != NavigationTabId.search).toList(growable: false);

  bool get _hasSearch => visibleTabs.any((tab) => tab.id == NavigationTabId.search);

  int? get _librariesSegmentIndex {
    if (isOfflineMode && onReconnect != null) return null;
    final index = _centerTabs.indexWhere((tab) => tab.id == NavigationTabId.libraries);
    return index < 0 ? null : index;
  }

  List<GlassSegment> _buildCenterSegments(BuildContext context) {
    return [for (final tab in _centerTabs) GlassSegment(label: tab.getLabel())];
  }

  int _selectedCenterIndex() {
    final index = _centerTabs.indexWhere((tab) => tab.id == selectedTab);
    return index < 0 ? 0 : index;
  }

  void _handleCenterSegmentSelected(int index) {
    final tab = _centerTabs[index];
    if (tab.id == NavigationTabId.libraries) {
      onLibrariesSegmentSelected?.call();
    }
    onTabSelected(tab.id);
  }

  void _handlePointerHover(Offset localPosition, double width, int segmentCount) {
    final librariesIndex = _librariesSegmentIndex;
    if (librariesIndex == null || onLibrariesSegmentHover == null) return;
    if (segmentCount <= 0 || width <= 0) return;
    final segmentWidth = width / segmentCount;
    final hovered = (localPosition.dx / segmentWidth).floor().clamp(0, segmentCount - 1);
    if (hovered == librariesIndex) {
      onLibrariesSegmentHover!();
    }
  }

  Widget _buildSideIconButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    FocusNode? focusNode,
    bool isSelected = false,
  }) {
    final iconColor = Theme.of(context).colorScheme.onSurface;
    final glow = isSelected ? const Color(0x66FFFFFF) : null;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.select) {
          onPressed?.call();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown && onNavigateToContent != null) {
          onNavigateToContent!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: tooltip,
        child: GlassIconButton(
          icon: AppIcon(icon, fill: 1, size: 22, color: iconColor),
          onPressed: onPressed,
          size: 40,
          glowColor: glow,
        ),
      ),
    );
  }

  Widget _buildCenterControl(BuildContext context) {
    final segments = _buildCenterSegments(context);
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    final labelStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      color: Theme.of(context).colorScheme.onSurface,
    );

    final control = GlassSegmentedControl.scrollable(
      segments: segments,
      selectedIndex: _selectedCenterIndex().clamp(0, segments.length - 1),
      onSegmentSelected: _handleCenterSegmentSelected,
      height: height,
      borderRadius: 18,
      padding: const EdgeInsets.all(3),
      useOwnLayer: true,
      quality: embyChromeGlassQuality(),
      settings: embyChromeGlassSettings(context),
      indicatorColor: embySegmentIndicatorColor(context),
      selectedTextStyle: labelStyle,
      unselectedTextStyle: labelStyle.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 14),
      indicatorExpansion: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      indicatorPinchStrength: 0.35,
    );

    final scopedControl = embyGlassSegmentScope(context, child: control);

    final librariesIndex = _librariesSegmentIndex;
    if (librariesIndex == null || onLibrariesSegmentHover == null) {
      return scopedControl;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (event) {
        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) return;
        _handlePointerHover(event.localPosition, renderObject.size.width, segments.length);
      },
      child: scopedControl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final centerTabs = _centerTabs;
    if (!_hasSearch && centerTabs.isEmpty && !showFullscreenToggle) {
      return const SizedBox.shrink();
    }

    NavigationTab? searchTab;
    for (final tab in visibleTabs) {
      if (tab.id == NavigationTabId.search) {
        searchTab = tab;
        break;
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isOfflineMode && onReconnect != null) ...[
          _buildSideIconButton(
            context: context,
            icon: isReconnecting ? Symbols.sync_rounded : Symbols.wifi_rounded,
            tooltip: t.common.reconnect,
            onPressed: isReconnecting ? null : onReconnect,
          ),
          const SizedBox(width: 4),
        ],
        if (_hasSearch) ...[
          _buildSideIconButton(
            context: context,
            icon: Symbols.search_rounded,
            tooltip: searchTab?.getLabel() ?? t.common.search,
            onPressed: () => onTabSelected(NavigationTabId.search),
            focusNode: searchFocusNode,
            isSelected: selectedTab == NavigationTabId.search,
          ),
          const SizedBox(width: 4),
        ],
        if (centerTabs.isNotEmpty) _buildCenterControl(context),
        if (showFullscreenToggle) ...[
          const SizedBox(width: 4),
          _buildSideIconButton(
            context: context,
            icon: isFullscreen ? Symbols.fullscreen_exit_rounded : Symbols.fullscreen_rounded,
            tooltip: isFullscreen ? t.common.exitFullscreen : t.common.fullscreen,
            onPressed: onFullscreenToggle,
            focusNode: fullscreenFocusNode,
          ),
        ],
      ],
    );
  }
}

/// Scrollable library chips styled like Infuse secondary navigation.
class EmbyInfuseLibraryNav extends StatelessWidget {
  const EmbyInfuseLibraryNav({
    super.key,
    required this.libraries,
    required this.selectedLibraryKey,
    required this.onLibrarySelected,
    this.height = 36,
  });

  final List<MediaLibraryRef> libraries;
  final String? selectedLibraryKey;
  final ValueChanged<String> onLibrarySelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (libraries.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedIndex = libraries.indexWhere((lib) => lib.globalKey == selectedLibraryKey);
    final labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return embyGlassSegmentScope(
      context,
      child: GlassSegmentedControl.scrollable(
        segments: [for (final lib in libraries) GlassSegment(label: lib.title)],
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onSegmentSelected: (index) => onLibrarySelected(libraries[index].globalKey),
        height: height,
        borderRadius: 16,
        padding: const EdgeInsets.all(2),
        useOwnLayer: true,
        quality: embyChromeGlassQuality(),
        settings: embyChromeGlassSettings(context),
        indicatorColor: embySegmentIndicatorColor(context),
        selectedTextStyle: labelStyle,
        unselectedTextStyle: labelStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        indicatorExpansion: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}

/// Minimal library identity for the scrollable nav bar (avoids importing media types here).
class MediaLibraryRef {
  const MediaLibraryRef({required this.globalKey, required this.title});

  final String globalKey;
  final String title;
}
