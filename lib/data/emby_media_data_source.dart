import '../domain/media_data_source.dart';
import '../media/library_query.dart';
import '../media/media_item.dart';
import '../media/media_library.dart';
import '../services/emby_client.dart';
import '../services/playback_initialization_types.dart';

final class EmbyMediaDataSource implements MediaDataSource {
  EmbyMediaDataSource(this._client);

  final EmbyClient _client;

  @override
  Future<List<MediaLibrary>> getLibraries() => _client.fetchLibraries();

  @override
  Future<LibraryPage<MediaItem>> browse(String libraryId, LibraryQuery query) =>
      _client.fetchLibraryContent(libraryId, query);

  @override
  Future<MediaItem?> getItem(String id) => _client.fetchItem(id);

  @override
  Future<PlaybackInitializationResult> resolvePlayback(String itemId) async {
    final item = await _client.fetchItem(itemId);
    if (item == null) {
      throw StateError('Emby item not found: $itemId');
    }
    return _client.getPlaybackInitialization(
      PlaybackInitializationOptions(metadata: item, selectedMediaIndex: 0),
    );
  }
}
