import '../media/library_query.dart';
import '../media/media_item.dart';
import '../media/media_library.dart';
import '../services/playback_initialization_types.dart';

/// Unified read surface for UI/providers — hides Emby client details.
abstract interface class MediaDataSource {
  Future<List<MediaLibrary>> getLibraries();
  Future<LibraryPage<MediaItem>> browse(String libraryId, LibraryQuery query);
  Future<MediaItem?> getItem(String id);
  Future<PlaybackInitializationResult> resolvePlayback(String itemId);
}
