import 'dart:async';
import '../media/ids.dart';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:emby_player/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../focus/dpad_navigator.dart';
import '../focus/focus_memory_tracker.dart';
import '../media/media_library.dart';
import '../mixins/mounted_set_state_mixin.dart';
import '../navigation/navigation_tabs.dart';
import '../providers/hidden_libraries_provider.dart';
import '../providers/libraries_provider.dart';
import '../services/settings_service.dart';
import '../utils/platform_detector.dart';
import '../utils/scroll_utils.dart';
import '../utils/library_grouping.dart';
import '../providers/multi_server_provider.dart';
import '../services/fullscreen_state_manager.dart';
import '../theme/mono_tokens.dart';
import '../theme/emby_glass_theme.dart';
import '../i18n/strings.g.dart';
import 'emby_infuse_top_bar.dart';

enum _LibraryNavSection { visible, hidden }

sealed class _LibraryNavRow {
  final _LibraryNavSection section;

  const _LibraryNavRow({required this.section});
}

final class _LibraryServerHeaderRow extends _LibraryNavRow {
  final String serverId;
  final String serverName;

  const _LibraryServerHeaderRow({required super.section, required this.serverId, required this.serverName});
}

final class _LibraryItemRow extends _LibraryNavRow {
  final MediaLibrary library;
  final bool showServerName;

  const _LibraryItemRow({required super.section, required this.library, this.showServerName = false});
}

/// Reusable navigation rail item widget that handles focus, selection, and interaction
class NavigationRailItem extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final Widget label;
  final bool isSelected;
  final bool isFocused;
  final bool isCollapsed;
  final bool useSimpleLayout;
  final VoidCallback onTap;
  final FocusNode focusNode;
  final bool autofocus;
  final BorderRadius borderRadius;
  final double iconSize;
  final double horizontalPadding;
  final bool suppressSelectedBackground;

  /// Horizontal top bar vs legacy vertical rail layout.
  final Axis layoutAxis;

  /// Called when arrow toward content is pressed (right on rail, down on top bar).
  final VoidCallback? onNavigateRight;

  const NavigationRailItem({
    super.key,
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.isFocused,
    this.isCollapsed = false,
    this.useSimpleLayout = false,
    required this.onTap,
    required this.focusNode,
    this.autofocus = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(11)),
    this.iconSize = 22,
    this.horizontalPadding = 17,
    this.suppressSelectedBackground = false,
    this.layoutAxis = Axis.horizontal,
    this.onNavigateRight,
  });

  @override
  Widget build(BuildContext context) {
    final t = tokens(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showSelectedBackground = isSelected && !suppressSelectedBackground;

    Color? pillColor() {
      if (isCollapsed) {
        if (isFocused || showSelectedBackground) {
          return isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.78);
        }
        return null;
      }
      if (showSelectedBackground) {
        return isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.82);
      }
      if (isFocused) {
        return isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white.withValues(alpha: 0.55);
      }
      return null;
    }

    final effectiveRadius = isCollapsed ? BorderRadius.circular(12) : borderRadius;

    if (isCollapsed) {
      return Focus(
        focusNode: focusNode,
        autofocus: autofocus,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey.isSelectKey) {
            onTap();
            return KeyEventResult.handled;
          }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && onNavigateRight != null) {
          onNavigateRight!();
          return KeyEventResult.handled;
        }
        if (layoutAxis == Axis.horizontal &&
            event.logicalKey == LogicalKeyboardKey.arrowDown &&
            onNavigateRight != null) {
          onNavigateRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: effectiveRadius,
          child: AnimatedContainer(
            duration: t.normal,
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: pillColor(), borderRadius: effectiveRadius),
              child: AppIcon(
                isSelected && selectedIcon != null ? selectedIcon! : icon,
                fill: 1,
                size: iconSize,
                color: isSelected ? t.text : t.textMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey.isSelectKey) {
          onTap();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight && onNavigateRight != null) {
          onNavigateRight!();
          return KeyEventResult.handled;
        }
        if (layoutAxis == Axis.horizontal &&
            event.logicalKey == LogicalKeyboardKey.arrowDown &&
            onNavigateRight != null) {
          onNavigateRight!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          canRequestFocus: false,
          onTap: onTap,
          borderRadius: borderRadius,
          child: AnimatedContainer(
            duration: t.normal,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: pillColor(),
              borderRadius: borderRadius,
              border: showSelectedBackground && !isCollapsed
                  ? Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.65),
                      width: 0.5,
                    )
                  : null,
              boxShadow: showSelectedBackground && !isDark && !isCollapsed
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            clipBehavior: Clip.hardEdge,
            child: layoutAxis == Axis.horizontal
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isCollapsed ? 0 : 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          isSelected && selectedIcon != null ? selectedIcon! : icon,
                          fill: 1,
                          size: iconSize,
                          color: isSelected ? t.text : t.textMuted,
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(width: 8),
                          DefaultTextStyle.merge(
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? t.text : t.textMuted,
                            ),
                            child: label,
                          ),
                        ],
                      ],
                    ),
                  )
                : UnconstrainedBox(
              alignment: .centerLeft,
              constrainedAxis: Axis.vertical,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: SideNavigationRailState.expandedWidth - 28,
                child: Padding(
                  padding: .symmetric(vertical: 12, horizontal: horizontalPadding),
                  child: Row(
                    children: [
                      AppIcon(
                        isSelected && selectedIcon != null ? selectedIcon! : icon,
                        fill: 1,
                        size: iconSize,
                        color: isSelected ? t.text : t.textMuted,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: () {
                          if (useSimpleLayout) return label;
                          final opacity = isCollapsed ? 0.0 : 1.0;
                          return AnimatedOpacity(opacity: opacity, duration: t.fast, child: label);
                        }(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Side navigation rail for Desktop and Android TV platforms
class SideNavigationRail extends StatefulWidget {
  final NavigationTabId selectedTab;
  final String? selectedLibraryKey;
  final bool isOfflineMode;
  final bool isSidebarFocused;
  final bool alwaysExpanded;
  final bool isReconnecting;
  final ValueChanged<NavigationTabId> onDestinationSelected;
  final ValueChanged<String> onLibrarySelected;

  /// Called when DOWN arrow is pressed to navigate to content without selecting.
  final VoidCallback? onNavigateToContent;

  /// Called when hover/touch expansion changes, so the shell can reserve width.
  final ValueChanged<bool>? onInteractionExpandedChanged;

  /// Called when chrome height changes (e.g. libraries sub-row toggled).
  final VoidCallback? onChromeLayoutChanged;

  /// Called when the user taps the reconnect button in offline mode.
  final VoidCallback? onReconnect;

  const SideNavigationRail({
    super.key,
    required this.selectedTab,
    this.selectedLibraryKey,
    this.isOfflineMode = false,
    this.isSidebarFocused = false,
    this.alwaysExpanded = false,
    this.isReconnecting = false,
    required this.onDestinationSelected,
    required this.onLibrarySelected,
    this.onNavigateToContent,
    this.onInteractionExpandedChanged,
    this.onChromeLayoutChanged,
    this.onReconnect,
  });

  @override
  State<SideNavigationRail> createState() => SideNavigationRailState();
}

class SideNavigationRailState extends State<SideNavigationRail> with MountedSetStateMixin, TickerProviderStateMixin {
  bool _librariesMenuVisible = false;
  bool _chromeClusterHovered = false;
  Timer? _librariesHideTimer;
  late final GlassMorphController _librariesRevealMorph;
  static const Duration _librariesHideDelay = Duration(milliseconds: 400);
  static const double collapsedWidth = 70.0;
  static const double tvCollapsedWidth = 52.0;
  static const double expandedWidth = 248.0;
  static const double barHeight = 48.0;
  static const double librarySubRowHeight = 44.0;
  static const double topChromePadding = 10.0;
  static const double _horizontalPadding = 10.0;
  static const double _itemHorizontalPadding = 17.0;
  static const double _defaultIconSize = 22.0;

  static double collapsedWidthForContext(BuildContext _) => PlatformDetector.isTV() ? tvCollapsedWidth : collapsedWidth;

  static double topChromeRowOffset(BuildContext context) {
    var top = MediaQuery.paddingOf(context).top + topChromePadding;
    if (Platform.isMacOS && !FullscreenStateManager().isFullscreen) {
      top = top < 52 ? 52 : top;
    }
    return top;
  }

  static double reservedHeightForContext(BuildContext context) {
    return topChromeRowOffset(context) + barHeight + topChromePadding;
  }

  static double currentHeightForContext(BuildContext context, {required double librariesRevealExtent}) {
    var height = reservedHeightForContext(context);
    height += (librarySubRowHeight + 6) * librariesRevealExtent.clamp(0.0, 1.0);
    return height;
  }

  double get librariesRevealExtent {
    if (!_librariesRevealMorph.isShowing) return 0;
    return _librariesRevealMorph.computeState(finalDx: 0, finalDy: 0).sizeT.clamp(0.0, 1.0);
  }

  bool get librariesExpanded => librariesRevealExtent > 0.001;

  void _notifyChromeLayoutChanged() {
    final callback = widget.onChromeLayoutChanged;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback();
    });
  }

  void _openLibrariesMenu() {
    _librariesHideTimer?.cancel();
    if (!_librariesMenuVisible) {
      setState(() => _librariesMenuVisible = true);
      _notifyChromeLayoutChanged();
    }
    _librariesRevealMorph.open();
  }

  @visibleForTesting
  void debugOpenLibrariesMenu() => _openLibrariesMenu();

  void _scheduleCloseLibrariesMenu() {
    _librariesHideTimer?.cancel();
    _librariesHideTimer = Timer(_librariesHideDelay, () {
      if (!mounted || _chromeClusterHovered) return;
      if (_librariesMenuVisible) {
        setState(() => _librariesMenuVisible = false);
        _librariesRevealMorph.close();
        _notifyChromeLayoutChanged();
      }
    });
  }

  void _closeLibrariesMenu() {
    _librariesHideTimer?.cancel();
    if (_librariesMenuVisible) {
      setState(() => _librariesMenuVisible = false);
      _notifyChromeLayoutChanged();
    }
    if (_librariesRevealMorph.isShowing) {
      _librariesRevealMorph.close();
    }
  }

  static double itemHorizontalPaddingForContext(BuildContext context, {required bool isCollapsed}) {
    if (isCollapsed && PlatformDetector.isTV()) {
      return ((tvCollapsedWidth - _defaultIconSize) / 2).clamp(0.0, _itemHorizontalPadding).toDouble();
    }
    return _itemHorizontalPadding;
  }

  static double horizontalPaddingForContext(BuildContext context, {required bool isCollapsed}) {
    if (!isCollapsed) return _horizontalPadding;
    return 4;
  }

  static const _kHome = 'home';
  static const _kLibraries = 'libraries';
  static const _kSearch = 'search';
  static const _kDownloads = 'downloads';
  static const _kSettings = 'settings';
  static const _kReconnect = 'reconnect';
  static const _kFullscreen = 'fullscreen';
  static const _kHiddenLibraries = 'hiddenLibraries';
  static const _kServerHeaderPrefix = 'serverHeader';
  static const _kLibraryItemPrefix = 'library';

  bool _hiddenLibrariesExpanded = false;
  final Set<String> _collapsedServerGroupKeys = {};

  // Unified focus state tracker for all nav items (main + libraries)
  late final FocusMemoryTracker _focusTracker;

  bool get _showDownloads => !PlatformDetector.isAppleTV();

  /// macOS has the system green button; mobile/TV have no OS fullscreen toggle.
  bool get _showFullscreenToggle => Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _librariesRevealMorph = GlassMorphController(vsync: this, speed: MorphSpeed.fast);
    _librariesRevealMorph.addListener(_onLibrariesRevealTick);
    _focusTracker = FocusMemoryTracker(
      onFocusChanged: () {
        // ignore: no-empty-block - setState triggers rebuild to update focus styling
        setStateIfMounted(() {});
      },
      debugLabelPrefix: 'nav',
    );
  }

  bool _librariesRevealTickScheduled = false;

  void _onLibrariesRevealTick() {
    if (_librariesRevealTickScheduled || !mounted) return;
    _librariesRevealTickScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _librariesRevealTickScheduled = false;
      if (!mounted) return;
      setStateIfMounted(() {});
      _notifyChromeLayoutChanged();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _librariesRevealMorph.setDisableAnimations(MediaQuery.disableAnimationsOf(context));
  }

  @override
  void dispose() {
    _librariesHideTimer?.cancel();
    _librariesRevealMorph.removeListener(_onLibrariesRevealTick);
    _librariesRevealMorph.dispose();
    _focusTracker.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SideNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab == widget.selectedTab &&
        oldWidget.selectedLibraryKey == widget.selectedLibraryKey) {
      return;
    }
    _librariesHideTimer?.cancel();
    if (!_librariesMenuVisible) return;
    // Parent is already rebuilding us — don't setState or notify chrome synchronously.
    _librariesMenuVisible = false;
    _librariesRevealMorph.close();
    _notifyChromeLayoutChanged();
  }

  /// The key of the last focused sidebar item (for pre-capture before focus shifts).
  String? get lastFocusedKey => _focusTracker.lastFocusedKey;

  /// Focus the last focused nav item, or Home as fallback.
  /// If [targetKey] is provided, try it first (used when the caller captured
  /// the intended target before a focus-scope switch overwrote it).
  void focusActiveItem({String? targetKey}) {
    final node = _resolveFocusNode(targetKey) ?? _mountedFocusNodeFor(_kHome);
    if (node == null) return;
    _requestFocusAndReveal(node);
  }

  /// Focus the Home nav item (Back returning to the home tab).
  void focusHomeItem() {
    final node = _mountedFocusNodeFor(_kHome);
    if (node == null) return;
    _requestFocusAndReveal(node);
  }

  /// Resolve the best mounted focus node in priority order:
  /// 1. Explicit [targetKey] (captured before scope switch)
  /// 2. Last focused key still in the tracker
  /// 3. Currently selected navigation item (tab / library)
  /// 4. Home fallback
  FocusNode? _resolveFocusNode(String? targetKey) {
    return _mountedFocusNodeFor(targetKey) ??
        _mountedFocusNodeFor(_focusTracker.lastFocusedKey) ??
        _mountedFocusNodeFor(_resolveSelectedFocusKey());
  }

  FocusNode? _mountedFocusNodeFor(String? key) {
    if (key == null) return null;
    final node = _focusTracker.nodeFor(key);
    return node?.context == null ? null : node;
  }

  /// Derive a focus key from the current selection state (tab + library).
  /// Returns null if no meaningful selected item exists.
  String? _resolveSelectedFocusKey() {
    switch (widget.selectedTab) {
      case NavigationTabId.discover:
        return _kHome;
      case NavigationTabId.libraries:
        final libKey = widget.selectedLibraryKey;
        if (libKey != null && _librariesMenuVisible) {
          final visibleKey = '$_kLibraryItemPrefix:${_LibraryNavSection.visible.name}:$libKey';
          if (_mountedFocusNodeFor(visibleKey) != null) return visibleKey;
          if (_hiddenLibrariesExpanded) {
            final hiddenKey = '$_kLibraryItemPrefix:${_LibraryNavSection.hidden.name}:$libKey';
            if (_mountedFocusNodeFor(hiddenKey) != null) return hiddenKey;
          }
        }
        return _kLibraries;
      case NavigationTabId.search:
        return _kSearch;
      case NavigationTabId.downloads:
        return _showDownloads ? _kDownloads : null;
      case NavigationTabId.settings:
        return _kSettings;
      case NavigationTabId.liveTv:
        return 'liveTv';
    }
  }

  /// Request focus on [node] and scroll it into view after the next frame.
  void _requestFocusAndReveal(FocusNode node) {
    node.requestFocus();
    scrollContextToCenter(node.context);
  }

  String _serverHeaderFocusKey(_LibraryNavSection section, ServerId serverId) =>
      '$_kServerHeaderPrefix:${section.name}:$serverId';

  String _libraryItemFocusKey(_LibraryNavSection section, MediaLibrary library) =>
      '$_kLibraryItemPrefix:${section.name}:${library.globalKey}';

  String _serverGroupStateKey(_LibraryNavSection section, ServerId serverId) => '${section.name}:$serverId';

  String _focusKeyForLibraryRow(_LibraryNavRow row) => switch (row) {
    _LibraryServerHeaderRow(:final section, :final serverId) => _serverHeaderFocusKey(section, ServerId(serverId)),
    _LibraryItemRow(:final section, :final library) => _libraryItemFocusKey(section, library),
  };

  Iterable<String> _focusKeysForLibraryRows(List<_LibraryNavRow> rows) => rows.map(_focusKeyForLibraryRow);

  /// Build the set of valid focus keys (main nav + currently rendered library rows).
  Set<String> _buildValidFocusKeys({
    required List<_LibraryNavRow> visibleRows,
    required List<_LibraryNavRow> hiddenRows,
    required bool hasHiddenLibraries,
    required bool hasLiveTv,
  }) {
    return {
      _kHome,
      _kLibraries,
      _kSearch,
      if (_showDownloads) _kDownloads,
      _kSettings,
      _kReconnect,
      if (hasHiddenLibraries) _kHiddenLibraries,
      if (_showFullscreenToggle) _kFullscreen,
      if (hasLiveTv) 'liveTv',
      ..._focusKeysForLibraryRows(visibleRows),
      if (_hiddenLibrariesExpanded) ..._focusKeysForLibraryRows(hiddenRows),
    };
  }

  /// Build rendered rows inside one library section. This is the single source
  /// of truth for both widget rendering and D-pad focus ordering.
  List<_LibraryNavRow> _buildLibraryRows(
    List<MediaLibrary> libs, {
    required _LibraryNavSection section,
    required bool showServerHeaders,
  }) {
    if (!showServerHeaders) {
      final nonUniqueNames = _getNonUniqueLibraryNames(libs);
      return libs.map((lib) {
        return _LibraryItemRow(
          section: section,
          library: lib,
          showServerName: nonUniqueNames.contains(lib.title) && lib.serverName != null,
        );
      }).toList();
    }
    final grouped = groupLibrariesByFirstAppearance(libs);
    final result = <_LibraryNavRow>[];
    for (final serverKey in grouped.serverOrder) {
      final bucket = grouped.byServer[serverKey]!;
      if (serverKey.isNotEmpty) {
        result.add(
          _LibraryServerHeaderRow(
            section: section,
            serverId: serverKey,
            serverName: bucket.first.serverName ?? serverKey,
          ),
        );
      }
      if (serverKey.isEmpty ||
          !_collapsedServerGroupKeys.contains(_serverGroupStateKey(section, ServerId(serverKey)))) {
        for (final lib in bucket) {
          result.add(_LibraryItemRow(section: section, library: lib));
        }
      }
    }
    return result;
  }

  Set<String> _buildServerGroupStateKeys(
    List<MediaLibrary> visibleLibraries,
    List<MediaLibrary> hiddenLibraries, {
    required bool showServerHeaders,
  }) {
    if (!showServerHeaders) return {};

    return {
      for (final lib in visibleLibraries)
        if (lib.serverId != null) _serverGroupStateKey(_LibraryNavSection.visible, ServerId(lib.serverId!)),
      for (final lib in hiddenLibraries)
        if (lib.serverId != null) _serverGroupStateKey(_LibraryNavSection.hidden, ServerId(lib.serverId!)),
    };
  }

  /// Ordered list of focusable keys matching visual top-to-bottom order.
  List<String> _buildFocusOrder(
    List<_LibraryNavRow> visibleRows,
    List<_LibraryNavRow> hiddenRows, {
    required bool hasHiddenLibraries,
    required bool hasLiveTv,
  }) {
    return [
      if (widget.isOfflineMode && widget.onReconnect != null) _kReconnect,
      if (!widget.isOfflineMode) ...[
        _kHome,
        _kLibraries,
        if (_librariesMenuVisible) ...[
          ..._focusKeysForLibraryRows(visibleRows),
          if (hasHiddenLibraries) ...[
            _kHiddenLibraries,
            if (_hiddenLibrariesExpanded) ..._focusKeysForLibraryRows(hiddenRows),
          ],
        ],
        if (hasLiveTv) 'liveTv',
        _kSearch,
      ],
      if (_showDownloads) _kDownloads,
      _kSettings,
      if (_showFullscreenToggle) _kFullscreen,
    ];
  }

  void _debugAssertUniqueFocusOrder(List<String> focusOrder) {
    assert(() {
      final seen = <String>{};
      for (final key in focusOrder) {
        if (!seen.add(key)) {
          throw FlutterError('SideNavigationRail focus order contains duplicate key: $key');
        }
      }
      return true;
    }());
  }

  /// Handle D-pad navigation by explicitly moving focus to the next/previous item.
  KeyEventResult _handleNavKeyNavigation(FocusNode _, KeyEvent event, List<String> focusOrder) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isNext = event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowRight;
    final isPrev = event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.arrowLeft;
    if (!isNext && !isPrev) return KeyEventResult.ignored;

    final currentKey = _focusTracker.lastFocusedKey;
    if (currentKey == null) return KeyEventResult.ignored;

    final currentIndex = focusOrder.indexOf(currentKey);
    if (currentIndex == -1) return KeyEventResult.ignored;

    final nextIndex = isNext ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex < 0 || nextIndex >= focusOrder.length) return KeyEventResult.handled;

    final nextNode = _focusTracker.nodeFor(focusOrder[nextIndex]);
    if (nextNode == null) return KeyEventResult.ignored;

    _requestFocusAndReveal(nextNode);
    return KeyEventResult.handled;
  }

  /// Collapse flyouts (libraries menu).
  void collapse() {
    _closeLibrariesMenu();
  }

  /// Reload libraries (called when servers change or profile switches)
  void reloadLibraries() {
    final librariesProvider = context.read<LibrariesProvider>();
    librariesProvider.refresh();
  }

  IconData _getLibraryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return Symbols.movie_rounded;
      case 'show':
        return Symbols.tv_rounded;
      case 'artist':
        return Symbols.music_note_rounded;
      case 'photo':
        return Symbols.photo_rounded;
      case 'mixed':
        return Symbols.share_rounded;
      default:
        return Symbols.folder_rounded;
    }
  }

  Widget _buildChromeGlassShell({required Widget child}) {
    return GlassContentAwareBrightness(
      builder: (context, brightness, darkAmount) {
        final onSurface = Color.lerp(const Color(0xFF101018), Colors.white, darkAmount)!;
        final themedChild = Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              onSurface: onSurface,
              onSurfaceVariant: onSurface.withValues(alpha: 0.72),
            ),
          ),
          child: child,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: AnimatedOpacity(
            opacity: PlatformDetector.isTV() ? 0.0 : 1.0,
            duration: tokens(context).normal,
            curve: Curves.easeOutCubic,
            child: themedChild,
          ),
        );
      },
    );
  }

  Widget _buildGlassPill({required Widget child, double height = barHeight}) {
    return _buildChromeGlassShell(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height, maxHeight: height),
        child: child,
      ),
    );
  }

  Widget _buildAnimatedLibrariesBar({
    required List<_LibraryNavRow> visibleRows,
    required List<_LibraryNavRow> hiddenRows,
    required int hiddenLibraryCount,
    required dynamic t,
    required double itemHorizontalPadding,
  }) {
    if (!_librariesRevealMorph.isShowing) return const SizedBox.shrink();

    final progress = _librariesRevealMorph.computeState(finalDx: 0, finalDy: 0).sizeT.clamp(0.0, 1.0);
    if (progress <= 0) return const SizedBox.shrink();

    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: progress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          child: _buildLibrariesSubRow(
            visibleRows,
            hiddenRows,
            hiddenLibraryCount,
            t,
            itemHorizontalPadding: itemHorizontalPadding,
            wrapInGlass: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = tokens(context);
    final librariesProvider = context.watch<LibrariesProvider>();
    final hiddenLibrariesProvider = context.watch<HiddenLibrariesProvider>();
    final hiddenKeys = hiddenLibrariesProvider.hiddenLibraryKeys;

    final allLibraries = librariesProvider.libraries;
    final visibleLibraries = <MediaLibrary>[];
    final hiddenLibraries = <MediaLibrary>[];
    final serverIds = <String>{};
    for (final lib in allLibraries) {
      if (lib.serverId != null) serverIds.add(lib.serverId!);
      if (hiddenKeys.contains(lib.globalKey)) {
        hiddenLibraries.add(lib);
      } else {
        visibleLibraries.add(lib);
      }
    }

    const itemHorizontalPadding = 12.0;
    final hasLiveTv = context.watch<MultiServerProvider>().hasLiveTv;

    // Listen to fullscreen + groupLibrariesByServer setting so the rail
    // rebuilds when the user toggles "Group libraries by server" in Appearance.
    return ListenableBuilder(
      listenable: Listenable.merge([
        FullscreenStateManager(),
        SettingsService.instance.listenable(SettingsService.groupLibrariesByServer),
      ]),
      builder: (context, _) {
        // Server grouping: only when multi-server AND the user-facing toggle is on.
        final groupByServerSetting = SettingsService.instance.read(SettingsService.groupLibrariesByServer);
        final showServerHeaders = serverIds.length > 1 && groupByServerSetting;
        _collapsedServerGroupKeys.retainAll(
          _buildServerGroupStateKeys(visibleLibraries, hiddenLibraries, showServerHeaders: showServerHeaders),
        );
        final visibleRows = _buildLibraryRows(
          visibleLibraries,
          section: _LibraryNavSection.visible,
          showServerHeaders: showServerHeaders,
        );
        final hiddenRows = _buildLibraryRows(
          hiddenLibraries,
          section: _LibraryNavSection.hidden,
          showServerHeaders: showServerHeaders,
        );
        _focusTracker.pruneExcept(
          _buildValidFocusKeys(
            visibleRows: visibleRows,
            hiddenRows: hiddenRows,
            hasHiddenLibraries: hiddenLibraries.isNotEmpty,
            hasLiveTv: hasLiveTv,
          ),
        );
        final focusOrder = _buildFocusOrder(
          visibleRows,
          hiddenRows,
          hasHiddenLibraries: hiddenLibraries.isNotEmpty,
          hasLiveTv: hasLiveTv,
        );
        _debugAssertUniqueFocusOrder(focusOrder);
        final topInset = topChromeRowOffset(context);
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topInset),
            child: MouseRegion(
              onEnter: (_) {
                _chromeClusterHovered = true;
                _librariesHideTimer?.cancel();
              },
              onExit: (_) {
                _chromeClusterHovered = false;
                _scheduleCloseLibrariesMenu();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: (node, event) => _handleNavKeyNavigation(node, event, focusOrder),
                        child: _buildChromeGlassShell(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: barHeight, maxHeight: barHeight),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: EmbyInfuseSegmentedNav(
                                    visibleTabs: NavigationTab.getVisibleTabs(
                                      isOffline: widget.isOfflineMode,
                                      hasLiveTv: hasLiveTv,
                                    ),
                                    selectedTab: widget.selectedTab,
                                    onTabSelected: widget.onDestinationSelected,
                                    onLibrariesSegmentHover: _openLibrariesMenu,
                                    onLibrariesSegmentSelected: _openLibrariesMenu,
                                    isOfflineMode: widget.isOfflineMode,
                                    isReconnecting: widget.isReconnecting,
                                    onReconnect: widget.onReconnect,
                                    showFullscreenToggle: _showFullscreenToggle,
                                    isFullscreen: FullscreenStateManager().isFullscreen,
                                    onFullscreenToggle: () => unawaited(FullscreenStateManager().toggleFullscreen()),
                                    searchFocusNode: _focusTracker.get(_kSearch),
                                    fullscreenFocusNode: _focusTracker.get(_kFullscreen),
                                    onNavigateToContent: widget.onNavigateToContent,
                                  ),
                                ),
                              ),
                              _buildAnimatedLibrariesBar(
                                visibleRows: visibleRows,
                                hiddenRows: hiddenRows,
                                hiddenLibraryCount: hiddenLibraries.length,
                                t: t,
                                itemHorizontalPadding: itemHorizontalPadding,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildLibrariesSubRow(
    List<_LibraryNavRow> visibleRows,
    List<_LibraryNavRow> hiddenRows,
    int hiddenLibraryCount,
    dynamic t, {
    required double itemHorizontalPadding,
    bool wrapInGlass = true,
  }) {
    final librariesProvider = context.watch<LibrariesProvider>();
    final isLoading = librariesProvider.isLoading;
    final allEmpty = visibleRows.isEmpty && hiddenLibraryCount == 0;

    final inner = Padding(
      padding: EdgeInsets.symmetric(horizontal: itemHorizontalPadding, vertical: 4),
      child: isLoading
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : allEmpty
              ? Center(
                  child: Text(
                    Translations.of(context).libraries.noLibrariesFound,
                    style: TextStyle(fontSize: 12, color: t.textMuted),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmbyInfuseLibraryNav(
                        libraries: [
                          for (final row in visibleRows)
                            if (row is _LibraryItemRow)
                              MediaLibraryRef(globalKey: row.library.globalKey, title: row.library.title),
                        ],
                        selectedLibraryKey: widget.selectedLibraryKey,
                        onLibrarySelected: (key) {
                          widget.onLibrarySelected(key);
                          _closeLibrariesMenu();
                        },
                      ),
                      if (hiddenLibraryCount > 0) ...[
                        const SizedBox(width: 6),
                        _buildHiddenLibrariesHeader(hiddenLibraryCount, t),
                        if (_hiddenLibrariesExpanded)
                          for (final row in hiddenRows)
                            if (row is _LibraryItemRow) ...[
                              const SizedBox(width: 4),
                              _buildHorizontalLibraryChip(row.library, t),
                            ],
                      ],
                    ],
                  ),
                ),
    );

    if (!wrapInGlass) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: librarySubRowHeight, maxHeight: librarySubRowHeight),
        child: inner,
      );
    }

    return _buildGlassPill(
      height: librarySubRowHeight,
      child: inner,
    );
  }

  Widget _buildHorizontalLibraryChip(MediaLibrary library, dynamic t) {
    final isSelected =
        widget.selectedTab == NavigationTabId.libraries && widget.selectedLibraryKey == library.globalKey;

    return GlassListTile.standalone(
      quality: embyChromeGlassQuality(),
      leading: AppIcon(_getLibraryIcon(library.kind.id), fill: 1, size: 20),
      title: Text(
        library.title,
        style: TextStyle(fontSize: 13, color: isSelected ? t.text : t.textMuted),
        overflow: TextOverflow.ellipsis,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () {
        widget.onLibrarySelected(library.globalKey);
        _closeLibrariesMenu();
      },
    );
  }

  Widget _buildHiddenLibrariesHeader(int count, dynamic t) {
    return GlassListTile.standalone(
      quality: embyChromeGlassQuality(),
      leading: const AppIcon(Symbols.visibility_off_rounded, fill: 1, size: 18),
      title: Text(
        Translations.of(context).libraries.hiddenLibrariesCount(count: count),
        style: TextStyle(fontSize: 12, color: t.textMuted),
      ),
      trailing: AppIcon(
        _hiddenLibrariesExpanded ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
        fill: 1,
        size: 18,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onTap: () => setState(() => _hiddenLibrariesExpanded = !_hiddenLibrariesExpanded),
    );
  }

  /// Get set of library names that appear more than once (not globally unique)
  Set<String> _getNonUniqueLibraryNames(List<MediaLibrary> libraries) {
    final nameCounts = <String, int>{};
    for (final lib in libraries) {
      nameCounts[lib.title] = (nameCounts[lib.title] ?? 0) + 1;
    }
    return nameCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
  }
}
