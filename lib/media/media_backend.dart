import '../utils/app_logger.dart';

/// Backend identifier for a media item, library, or server.
enum MediaBackend {
  emby,
  jellyfin;

  /// Deprecated Plex alias — legacy persisted items may still reference `plex`.
  static MediaBackend get plex => emby;

  String get id => name;

  static MediaBackend fromId(String id) => switch (id) {
    'emby' => MediaBackend.emby,
    'jellyfin' => MediaBackend.jellyfin,
    'plex' => MediaBackend.emby,
    _ => throw ArgumentError('Unknown MediaBackend id: $id'),
  };

  static MediaBackend fromString(String? id) {
    return switch (id) {
      'jellyfin' => MediaBackend.jellyfin,
      'emby' || 'plex' => MediaBackend.emby,
      null || '' => MediaBackend.emby,
      _ => () {
        appLogger.w('Unknown MediaBackend id "$id"; defaulting to emby');
        return MediaBackend.emby;
      }(),
    };
  }
}
