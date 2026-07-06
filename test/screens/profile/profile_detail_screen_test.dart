import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emby_player/connection/connection.dart';
import 'package:emby_player/connection/connection_registry.dart';
import 'package:emby_player/database/app_database.dart';
import 'package:emby_player/focus/input_mode_tracker.dart';
import 'package:emby_player/i18n/strings.g.dart';
import 'package:emby_player/profiles/plex_home_service.dart';
import 'package:emby_player/profiles/profile.dart';
import 'package:emby_player/profiles/profile_connection.dart';
import 'package:emby_player/profiles/profile_connection_registry.dart';
import 'package:emby_player/profiles/profile_registry.dart';
import 'package:emby_player/screens/profile/profile_detail_screen.dart';
import 'package:emby_player/services/storage_service.dart';
import 'package:emby_player/utils/platform_detector.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    resetSharedPreferencesForTest();
    TvDetectionService.debugSetAppleTVOverride(null);
    LocaleSettings.setLocaleSync(AppLocale.en);
  });

  tearDown(() {
    TvDetectionService.debugSetAppleTVOverride(null);
    PlatformDetector.debugSetIsDesktopOSOverride(null);
  });

  testWidgets('remote back pops the manage profile page', (tester) async {
    TvDetectionService.debugSetAppleTVOverride(true);
    // Simulated TV device, not desktop force-TV: keep locked keyboard mode.
    PlatformDetector.debugSetIsDesktopOSOverride(false);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final profile = Profile.local(id: 'local-owner', displayName: 'Owner', createdAt: DateTime(2026, 1, 1));
    final profiles = _FakeProfileRegistry(db, [profile]);
    final connections = _FakeConnectionRegistry(db);
    final profileConnections = _FakeProfileConnectionRegistry(db);
    final storage = await StorageService.getInstance();
    final plexHome = PlexHomeService(
      connections: connections,
      profileConnections: profileConnections,
      storage: storage,
      plexHomeUserFetcher: (_) async => const [],
    );
    addTearDown(() async {
      await plexHome.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      TranslationProvider(
        child: MultiProvider(
          providers: [
            Provider<ProfileRegistry>.value(value: profiles),
            Provider<ProfileConnectionRegistry>.value(value: profileConnections),
            Provider<ConnectionRegistry>.value(value: connections),
            Provider<PlexHomeService>.value(value: plexHome),
          ],
          child: InputModeTracker(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => ProfileDetailScreen(profile: profile)));
                      },
                      child: const Text('Open profile'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();
    expect(find.text(t.profiles.connectionsLabel), findsOneWidget);
    expect(find.byKey(const Key('tv_virtual_keyboard_panel')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pumpAndSettle();

    expect(find.text(t.profiles.connectionsLabel), findsOneWidget);
    expect(find.byKey(const Key('tv_virtual_keyboard_panel')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pumpAndSettle();

    expect(find.text('Open profile'), findsOneWidget);
    expect(find.text(t.profiles.connectionsLabel), findsNothing);
  });
}

class _FakeConnectionRegistry extends ConnectionRegistry {
  _FakeConnectionRegistry(super.db);

  @override
  Future<List<Connection>> list() async => const [];

  // Synthetic stream: a real drift watch leaves the stream store's
  // keep-alive timer pending when the test ends.
  @override
  Stream<List<Connection>> watchConnections() => Stream.value(const []);
}

class _FakeProfileRegistry extends ProfileRegistry {
  _FakeProfileRegistry(super.db, this._profiles);

  final List<Profile> _profiles;

  @override
  Stream<List<Profile>> watchProfiles() => Stream.value(_profiles);
}

class _FakeProfileConnectionRegistry extends ProfileConnectionRegistry {
  _FakeProfileConnectionRegistry(super.db);

  @override
  Stream<List<ProfileConnection>> watchForProfile(String profileId) => Stream.value(const []);
}
