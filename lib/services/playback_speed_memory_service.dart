import '../media/media_item.dart';
import '../media/media_item_types.dart';
import 'settings_service.dart';

/// Per-show playback speed memory (keyed by series / movie id).
class PlaybackSpeedMemoryService {
  PlaybackSpeedMemoryService._();

  static String? _speedKeyFor(MediaItem item) {
    if (item.isEpisode || item.isSeason) return item.grandparentId ?? item.parentId;
    if (item.isShow) return item.id;
    if (item.isMovie) return item.id;
    return null;
  }

  static double? rememberedSpeedFor(MediaItem item) {
    final settings = SettingsService.instanceOrNull;
    if (settings == null || !settings.read(SettingsService.rememberPlaybackSpeedPerShow)) return null;

    final key = _speedKeyFor(item);
    if (key == null) return null;
    final map = settings.read(SettingsService.playbackSpeedByShow);
    return map[key];
  }

  static Future<void> rememberSpeedFor(MediaItem item, double speed) async {
    final settings = SettingsService.instance;
    if (!settings.read(SettingsService.rememberPlaybackSpeedPerShow)) return;

    final key = _speedKeyFor(item);
    if (key == null) return;

    final map = Map<String, double>.from(settings.read(SettingsService.playbackSpeedByShow));
    map[key] = speed.clamp(0.5, 3.0);
    await settings.write(SettingsService.playbackSpeedByShow, map);
  }
}
