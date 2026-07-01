import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../mpv/mpv.dart';
import '../utils/app_logger.dart';
import 'settings_service.dart';

/// Loads user-provided mpv Lua scripts from the app data directory.
class MpvScriptService {
  MpvScriptService._();

  static const scriptsSubdir = 'mpv-scripts';

  /// `{appSupport}/mpv-scripts/` — place `.lua` scripts here.
  static Future<Directory> scriptsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, scriptsSubdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> scriptsDirectoryPath() async => (await scriptsDirectory()).path;

  /// List `.lua` files in the scripts directory (non-recursive).
  static Future<List<File>> listScriptFiles() async {
    final dir = await scriptsDirectory();
    final entries = await dir.list().toList();
    return [
      for (final e in entries)
        if (e is File && e.path.toLowerCase().endsWith('.lua')) e,
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Load enabled scripts into a running mpv instance via `load-script`.
  static Future<void> applyToPlayer(Player player) async {
    final settings = SettingsService.instanceOrNull;
    if (settings == null || !settings.read(SettingsService.mpvLoadUserScripts)) return;

    final scripts = await listScriptFiles();
    for (final file in scripts) {
      try {
        await player.command(['load-script', file.path]);
        appLogger.i('MPV: loaded script ${file.path}');
      } catch (e, st) {
        appLogger.w('MPV: failed to load script ${file.path}', error: e, stackTrace: st);
      }
    }
  }
}
