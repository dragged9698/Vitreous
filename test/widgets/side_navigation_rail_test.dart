import 'package:emby_player/media/ids.dart';
import 'package:emby_player/i18n/strings.g.dart';
import 'package:emby_player/media/media_backend.dart';
import 'package:emby_player/media/media_kind.dart';
import 'package:emby_player/media/media_library.dart';
import 'package:emby_player/navigation/navigation_tabs.dart';
import 'package:emby_player/providers/hidden_libraries_provider.dart';
import 'package:emby_player/providers/libraries_provider.dart';
import 'package:emby_player/providers/multi_server_provider.dart';
import 'package:emby_player/services/data_aggregation_service.dart';
import 'package:emby_player/services/multi_server_manager.dart';
import 'package:emby_player/services/settings_service.dart';
import 'package:emby_player/theme/mono_tokens.dart';
import 'package:emby_player/theme/emby_glass_theme.dart';
import 'package:emby_player/widgets/emby_infuse_top_bar.dart';
import 'package:emby_player/widgets/side_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test_helpers/prefs.dart';

const _testTokens = MonoTokens(
  radiusSm: 8,
  radiusMd: 12,
  space: 8,
  fast: Duration(milliseconds: 1),
  normal: Duration(milliseconds: 1),
  slow: Duration(milliseconds: 1),
  bg: Colors.black,
  surface: Colors.black,
  outline: Colors.white24,
  text: Colors.white,
  textMuted: Colors.white70,
  splashFactory: NoSplash.splashFactory,
);

MediaLibrary _library({
  required String id,
  required String title,
  required ServerId serverId,
  required String serverName,
}) {
  return MediaLibrary(
    id: id,
    backend: MediaBackend.plex,
    title: title,
    kind: MediaKind.movie,
    serverId: serverId,
    serverName: serverName,
  );
}

Future<void> _pumpTopBar(
  WidgetTester tester, {
  NavigationTabId selectedTab = NavigationTabId.discover,
  String? selectedLibraryKey,
  List<MediaLibrary> libraries = const [],
}) async {
  await SettingsService.getInstance();

  final librariesProvider = LibrariesProvider();
  if (libraries.isNotEmpty) {
    await librariesProvider.updateLibraryOrder(libraries);
  }
  addTearDown(librariesProvider.dispose);

  final hiddenLibrariesProvider = HiddenLibrariesProvider();
  await hiddenLibrariesProvider.ensureInitialized();
  addTearDown(hiddenLibrariesProvider.dispose);

  final manager = MultiServerManager();
  final aggregation = DataAggregationService(manager);
  final multiServerProvider = MultiServerProvider(manager, aggregation);
  addTearDown(multiServerProvider.dispose);

  await tester.pumpWidget(
    TranslationProvider(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<LibrariesProvider>.value(value: librariesProvider),
          ChangeNotifierProvider<HiddenLibrariesProvider>.value(value: hiddenLibrariesProvider),
          ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
        ],
        child: embyGlassWrapApp(
          child: MaterialApp(
            theme: ThemeData(extensions: const [_testTokens], brightness: Brightness.dark),
            home: Scaffold(
              body: SideNavigationRail(
                selectedTab: selectedTab,
                selectedLibraryKey: selectedLibraryKey,
                onDestinationSelected: (_) {},
                onLibrarySelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  testWidgets('renders Infuse-style segmented top navigation', (tester) async {
    await _pumpTopBar(tester);
    expect(find.byType(EmbyInfuseSegmentedNav), findsOneWidget);
    expect(find.byType(SideNavigationRail), findsOneWidget);
  });

  testWidgets('selecting Libraries reveals the library sub-bar', (tester) async {
    final libraries = [
      _library(id: '1', title: 'Movies', serverId: ServerId('server'), serverName: 'Server'),
      _library(id: '2', title: 'Shows', serverId: ServerId('server'), serverName: 'Server'),
    ];

    final sideNavKey = GlobalKey<SideNavigationRailState>();
    await SettingsService.getInstance();

    final librariesProvider = LibrariesProvider();
    await librariesProvider.updateLibraryOrder(libraries);
    addTearDown(librariesProvider.dispose);

    final hiddenLibrariesProvider = HiddenLibrariesProvider();
    await hiddenLibrariesProvider.ensureInitialized();
    addTearDown(hiddenLibrariesProvider.dispose);

    final manager = MultiServerManager();
    final aggregation = DataAggregationService(manager);
    final multiServerProvider = MultiServerProvider(manager, aggregation);
    addTearDown(multiServerProvider.dispose);

    NavigationTabId? selected = NavigationTabId.discover;
    await tester.pumpWidget(
      TranslationProvider(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<LibrariesProvider>.value(value: librariesProvider),
            ChangeNotifierProvider<HiddenLibrariesProvider>.value(value: hiddenLibrariesProvider),
            ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
          ],
          child: embyGlassWrapApp(
            child: MaterialApp(
              theme: ThemeData(extensions: const [_testTokens], brightness: Brightness.dark),
              home: Scaffold(
                body: SideNavigationRail(
                  key: sideNavKey,
                  selectedTab: selected!,
                  onDestinationSelected: (tab) => selected = tab,
                  onLibrarySelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    sideNavKey.currentState!.debugOpenLibrariesMenu();
    await tester.pumpAndSettle();

    expect(find.byType(EmbyInfuseLibraryNav), findsOneWidget);
  });

  testWidgets('top bar is aligned to the top center of the screen', (tester) async {
    await _pumpTopBar(tester);

    final align = tester.widget<Align>(
      find.descendant(of: find.byType(SideNavigationRail), matching: find.byType(Align)).first,
    );
    expect(align.alignment, Alignment.topCenter);
  });
}
