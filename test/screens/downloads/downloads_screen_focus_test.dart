import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emby_player/connection/connection.dart';
import 'package:emby_player/connection/connection_registry.dart';
import 'package:emby_player/database/app_database.dart';
import 'package:emby_player/focus/input_mode_tracker.dart';
import 'package:emby_player/providers/download_provider.dart';
import 'package:emby_player/providers/multi_server_provider.dart';
import 'package:emby_player/screens/downloads/downloads_screen.dart';
import 'package:emby_player/services/data_aggregation_service.dart';
import 'package:emby_player/services/download_manager_service.dart';
import 'package:emby_player/services/download_storage_service.dart';
import 'package:emby_player/services/jellyfin_api_cache.dart';
import 'package:emby_player/services/multi_server_manager.dart';
import 'package:emby_player/services/plex_api_cache.dart';
import 'package:emby_player/services/settings_service.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/prefs.dart';

class _FakeConnectionRegistry extends ConnectionRegistry {
  _FakeConnectionRegistry(super.db);

  @override
  Stream<List<Connection>> watchConnections() => Stream.value(const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DownloadProvider downloadProvider;
  late MultiServerProvider multiServerProvider;
  late MultiServerManager serverManager;

  setUp(() async {
    resetSharedPreferencesForTest();
    SettingsService.resetForTesting();
    await SettingsService.getInstance();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    PlexApiCache.initialize(db);
    JellyfinApiCache.initialize(db);

    final downloadManager = DownloadManagerService(
      database: db,
      storageService: DownloadStorageService.instance,
      clientResolver: (serverId, {clientScopeId}) => null,
    );
    downloadProvider = DownloadProvider.forTesting(downloadManager: downloadManager, database: db);
    await downloadProvider.ensureInitialized();

    serverManager = MultiServerManager();
    multiServerProvider = MultiServerProvider(serverManager, DataAggregationService(serverManager));
  });

  tearDown(() async {
    downloadProvider.dispose();
    multiServerProvider.dispose();
    await db.close();
  });

  testWidgets('right from Movies focuses and opens Sync Rules action', (tester) async {
    final screenKey = GlobalKey<DownloadsScreenState>();

    await tester.pumpWidget(
      InputModeTracker(
        child: MultiProvider(
          providers: [
            Provider<ConnectionRegistry>.value(value: _FakeConnectionRegistry(db)),
            ChangeNotifierProvider<DownloadProvider>.value(value: downloadProvider),
            ChangeNotifierProvider<MultiServerProvider>.value(value: multiServerProvider),
          ],
          child: MaterialApp(
            theme: ThemeData(platform: TargetPlatform.macOS),
            home: DownloadsScreen(key: screenKey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = screenKey.currentState!;
    state.tabController.index = 2;
    state.getTabChipFocusNode(2).requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Sync rules'), findsOneWidget);
  });
}
