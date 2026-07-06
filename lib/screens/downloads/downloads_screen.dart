import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../media/ids.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import '../../focus/focusable_action_bar.dart';
import '../../media/media_item.dart';
import '../../models/download_sort.dart';
import '../../providers/download_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../services/settings_service.dart';
import '../../widgets/settings_builder.dart';
import '../../utils/global_key_utils.dart';
import '../../mixins/tab_navigation_mixin.dart';
import '../../mixins/refreshable.dart';
import '../../utils/grid_size_calculator.dart';
import '../../utils/platform_detector.dart';
import '../../theme/emby_glass_theme.dart';
import '../../widgets/emby_glass_browse_shell.dart';
import '../../widgets/emby_glass_chrome.dart';
import '../../widgets/desktop_app_bar.dart';
import '../../widgets/focusable_media_card.dart';
import '../../widgets/media_grid_delegate.dart';
import '../../widgets/download_tree_view.dart';
import '../main_screen.dart';
import '../libraries/state_messages.dart';
import '../../i18n/strings.g.dart';
import 'sync_rules_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => DownloadsScreenState();
}

class DownloadsScreenState extends State<DownloadsScreen>
    with TickerProviderStateMixin, TabNavigationMixin, FocusableTab {
  final _manageTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_manage');
  final _browseTabChipFocusNode = FocusNode(debugLabel: 'tab_chip_browse');
  final _actionBarKey = GlobalKey<FocusableActionBarState>();
  String _selectedLibraryKey = 'all';

  @override
  List<FocusNode> get tabChipFocusNodes => [_manageTabChipFocusNode, _browseTabChipFocusNode];

  @override
  void initState() {
    super.initState();
    suppressAutoFocus = true;
    initTabNavigation();
  }

  @override
  void dispose() {
    _manageTabChipFocusNode.dispose();
    _browseTabChipFocusNode.dispose();
    disposeTabNavigation();
    super.dispose();
  }

  @override
  void onTabChanged() {
    if (!tabController.indexIsChanging) {
      super.onTabChanged();
    }
  }

  @override
  void focusActiveTabIfReady() {
    suppressAutoFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      getTabChipFocusNode(tabController.index).requestFocus();
    });
  }

  void _focusCurrentTab() {
    setState(() => suppressAutoFocus = false);
  }

  Widget _buildTabChip(String label, int index) {
    return buildTabChip(
      label,
      index,
      onSelectWhenActive: _focusCurrentTab,
      onNavigateDown: _focusCurrentTab,
      onNavigateToActions: () => _actionBarKey.currentState?.requestFocusOnFirst(),
    );
  }

  Widget _buildAppBarTitle() {
    if (PlatformDetector.shouldUseSideNavigation(context)) {
      return GlassSegmentedControl(
        segments: [
          GlassSegment(label: t.downloads.manage),
          GlassSegment(label: t.downloads.browse),
        ],
        selectedIndex: tabController.index,
        quality: embyChromeGlassQuality(),
        onSegmentSelected: (index) {
          tabController.animateTo(index);
          _focusCurrentTab();
        },
      );
    }
    return Text(t.downloads.title);
  }

  List<FocusableAction> _toolbarActions() => [
        if (tabController.index == 1) ...[
          FocusableAction(
            icon: Symbols.sort_rounded,
            tooltip: t.downloads.sortBy,
            onPressed: _showSortPicker,
          ),
          FocusableAction(
            icon: Symbols.filter_list_rounded,
            tooltip: t.downloads.filterBy,
            onPressed: _showFilterPicker,
          ),
        ],
        FocusableAction(
          icon: Symbols.rule_settings,
          tooltip: t.downloads.activeSyncRules,
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncRulesScreen())),
        ),
      ];

  List<Widget> _buildAppBarActions() => [
        FocusableActionBar(
          key: _actionBarKey,
          onNavigateLeft: () => getTabChipFocusNode(tabCount - 1).requestFocus(),
          onNavigateDown: _focusCurrentTab,
          actions: _toolbarActions(),
        ),
      ];

  Future<void> _showSortPicker() async {
    final settings = SettingsService.instance;
    final current = settings.read(SettingsService.downloadSortOrder);
    final picked = await showDialog<DownloadSortOrder>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.downloads.sortBy),
        children: [
          for (final option in DownloadSortOrder.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, option),
              child: Text(_sortLabel(option), style: TextStyle(fontWeight: option == current ? FontWeight.bold : null)),
            ),
        ],
      ),
    );
    if (picked != null) await settings.write(SettingsService.downloadSortOrder, picked);
  }

  Future<void> _showFilterPicker() async {
    final settings = SettingsService.instance;
    final current = settings.read(SettingsService.downloadFilterMode);
    final picked = await showDialog<DownloadFilterMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t.downloads.filterBy),
        children: [
          for (final option in DownloadFilterMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, option),
              child: Text(_filterLabel(option), style: TextStyle(fontWeight: option == current ? FontWeight.bold : null)),
            ),
        ],
      ),
    );
    if (picked != null) await settings.write(SettingsService.downloadFilterMode, picked);
  }

  String _sortLabel(DownloadSortOrder order) => switch (order) {
    DownloadSortOrder.titleAsc => t.downloads.sortTitleAsc,
    DownloadSortOrder.titleDesc => t.downloads.sortTitleDesc,
    DownloadSortOrder.dateAddedDesc => t.downloads.sortDateDesc,
    DownloadSortOrder.dateAddedAsc => t.downloads.sortDateAsc,
  };

  String _filterLabel(DownloadFilterMode mode) => switch (mode) {
    DownloadFilterMode.all => t.downloads.filterAll,
    DownloadFilterMode.unwatched => t.downloads.filterUnwatched,
    DownloadFilterMode.watched => t.downloads.filterWatched,
  };

  @override
  Widget build(BuildContext context) {
    final useGlassShell = PlatformDetector.shouldUseSideNavigation(context);
    final scrollView = CustomScrollView(
      primary: false,
      slivers: [
        if (!useGlassShell)
          DesktopSliverAppBar(
            title: _buildAppBarTitle(),
            floating: true,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            scrolledUnderElevation: 0,
            actions: _buildAppBarActions(),
          ),
        SliverFillRemaining(
          child: Column(
            children: [
              if (!useGlassShell)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabChip(t.downloads.manage, 0),
                        const SizedBox(width: 8),
                        _buildTabChip(t.downloads.browse, 1),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: tabController,
                  children: [
                    Consumer2<DownloadProvider, MultiServerProvider>(
                      builder: (context, downloadProvider, serverProvider, _) {
                        getClient(String globalKey) {
                          final serverId = parseGlobalKey(globalKey)?.serverId ?? globalKey;
                          return serverProvider.serverManager.getClient(ServerId(serverId));
                        }

                        return DownloadTreeView(
                          downloads: downloadProvider.downloads,
                          metadata: downloadProvider.metadata,
                          onPause: downloadProvider.pauseDownload,
                          onResume: (globalKey) {
                            final client = getClient(globalKey);
                            if (client != null) downloadProvider.resumeDownload(globalKey, client);
                          },
                          onRetry: (globalKey) {
                            final client = getClient(globalKey);
                            if (client != null) downloadProvider.retryDownload(globalKey, client);
                          },
                          onCancel: downloadProvider.cancelDownload,
                          onDelete: downloadProvider.deleteDownload,
                          onNavigateLeft: () => MainScreenFocusScope.of(context, listen: false)?.focusSidebar(),
                          onBack: focusTabBar,
                          suppressAutoFocus: suppressAutoFocus,
                        );
                      },
                    ),
                    _DownloadsBrowseTab(
                      selectedLibraryKey: _selectedLibraryKey,
                      onLibrarySelected: (key) => setState(() => _selectedLibraryKey = key),
                      suppressAutoFocus: suppressAutoFocus,
                      onBack: focusTabBar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (!useGlassShell) {
      return Scaffold(body: scrollView);
    }

    return EmbyGlassBrowseShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EmbyGlassPageToolbar(
            leading: EmbyGlassSegmentedControl(
              segments: [
                GlassSegment(label: t.downloads.manage),
                GlassSegment(label: t.downloads.browse),
              ],
              selectedIndex: tabController.index,
              onSegmentSelected: (index) {
                tabController.animateTo(index);
                _focusCurrentTab();
              },
            ),
            actionBarKey: _actionBarKey,
            onNavigateLeft: () => getTabChipFocusNode(tabCount - 1).requestFocus(),
            onNavigateDown: _focusCurrentTab,
            actions: _toolbarActions(),
          ),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                Consumer2<DownloadProvider, MultiServerProvider>(
                  builder: (context, downloadProvider, serverProvider, _) {
                    getClient(String globalKey) {
                      final serverId = parseGlobalKey(globalKey)?.serverId ?? globalKey;
                      return serverProvider.serverManager.getClient(ServerId(serverId));
                    }

                    return DownloadTreeView(
                      downloads: downloadProvider.downloads,
                      metadata: downloadProvider.metadata,
                      onPause: downloadProvider.pauseDownload,
                      onResume: (globalKey) {
                        final client = getClient(globalKey);
                        if (client != null) downloadProvider.resumeDownload(globalKey, client);
                      },
                      onRetry: (globalKey) {
                        final client = getClient(globalKey);
                        if (client != null) downloadProvider.retryDownload(globalKey, client);
                      },
                      onCancel: downloadProvider.cancelDownload,
                      onDelete: downloadProvider.deleteDownload,
                      onNavigateLeft: () => MainScreenFocusScope.of(context, listen: false)?.focusSidebar(),
                      onBack: focusTabBar,
                      suppressAutoFocus: suppressAutoFocus,
                    );
                  },
                ),
                _DownloadsBrowseTab(
                  selectedLibraryKey: _selectedLibraryKey,
                  onLibrarySelected: (key) => setState(() => _selectedLibraryKey = key),
                  suppressAutoFocus: suppressAutoFocus,
                  onBack: focusTabBar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsBrowseTab extends StatelessWidget {
  final String selectedLibraryKey;
  final ValueChanged<String> onLibrarySelected;
  final bool suppressAutoFocus;
  final VoidCallback? onBack;

  const _DownloadsBrowseTab({
    required this.selectedLibraryKey,
    required this.onLibrarySelected,
    required this.suppressAutoFocus,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, _) {
        final libraries = downloadProvider.downloadLibraryTabs;
        final libraryKey = selectedLibraryKey == 'all' || libraries.every((l) => l.key != selectedLibraryKey)
            ? 'all'
            : selectedLibraryKey;
        final items = libraryKey == 'all'
            ? [
                for (final tab in libraries) ...downloadProvider.downloadsForLibraryTab(tab.key),
              ]
            : downloadProvider.downloadsForLibraryTab(libraryKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (libraries.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t.downloads.allLibraries),
                        selected: libraryKey == 'all',
                        onSelected: (_) => onLibrarySelected('all'),
                      ),
                    ),
                    for (final lib in libraries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(lib.title),
                          selected: libraryKey == lib.key,
                          onSelected: (_) => onLibrarySelected(lib.key),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: items.isEmpty
                  ? EmptyStateWidget(message: t.downloads.noDownloads, subtitle: t.downloads.noDownloadsDescription)
                  : _DownloadsGridContent(items: items, suppressAutoFocus: suppressAutoFocus, onBack: onBack),
            ),
          ],
        );
      },
    );
  }
}

class _DownloadsGridContent extends StatefulWidget {
  final List<MediaItem> items;
  final bool suppressAutoFocus;
  final VoidCallback? onBack;

  const _DownloadsGridContent({required this.items, required this.suppressAutoFocus, this.onBack});

  @override
  State<_DownloadsGridContent> createState() => _DownloadsGridContentState();
}

class _DownloadsGridContentState extends State<_DownloadsGridContent> {
  final FocusNode _firstItemFocusNode = FocusNode(debugLabel: 'DownloadsGrid_firstItem');

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_DownloadsGridContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suppressAutoFocus && !widget.suppressAutoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _firstItemFocusNode.canRequestFocus) _firstItemFocusNode.requestFocus();
      });
    }
  }

  void _navigateToSidebar() {
    MainScreenFocusScope.of(context, listen: false)?.focusSidebar();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsBuilder(
      prefs: const [SettingsService.libraryDensity, SettingsService.tvFullCardLayout, SettingsService.downloadSortOrder, SettingsService.downloadFilterMode],
      builder: (context) {
        final settings = SettingsService.instance;
        final density = settings.read(SettingsService.libraryDensity);
        final fullCardLayout = PlatformDetector.isTV() && settings.read(SettingsService.tvFullCardLayout);
        final maxCrossAxisExtent = GridSizeCalculator.getMaxCrossAxisExtent(context, density);
        const effectivePadding = EdgeInsets.only(left: 8, right: 8, top: 8);

        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - effectivePadding.left - effectivePadding.right;
            final gridSpacing = MediaGridDelegate.spacingFor(context: context, fullBleedImage: fullCardLayout);
            final columnCount = GridSizeCalculator.getColumnCount(
              availableWidth,
              maxCrossAxisExtent,
              crossAxisSpacing: gridSpacing,
            );

            return GridView.builder(
              padding: effectivePadding,
              clipBehavior: Clip.none,
              gridDelegate: MediaGridDelegate.createDelegate(
                context: context,
                density: density,
                fullBleedImage: fullCardLayout,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final isFirstColumn = GridSizeCalculator.isFirstColumn(index, columnCount);
                final isFirst = index == 0;
                return FocusableMediaCard(
                  item: item,
                  focusNode: isFirst ? _firstItemFocusNode : null,
                  onBack: widget.onBack,
                  isOffline: true,
                  fullBleedImage: fullCardLayout,
                  onNavigateLeft: isFirstColumn ? _navigateToSidebar : null,
                );
              },
            );
          },
        );
      },
    );
  }
}
