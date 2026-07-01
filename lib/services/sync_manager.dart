import '../media/media_item.dart';
import '../media/media_server_client.dart';
import 'trackers/tracker_coordinator.dart';

/// Bridges Emby playback progress reporting with external tracker scrobbling.
class SyncManager {
  SyncManager({TrackerCoordinator? coordinator})
      : _coordinator = coordinator ?? TrackerCoordinator.instance;

  final TrackerCoordinator _coordinator;

  Future<void> onPlaybackStarted(MediaItem item, MediaServerClient client, {bool isLive = false}) async {
    await _coordinator.startPlayback(item, client, isLive: isLive);
  }

  void onProgress(Duration position, Duration duration) {
    _coordinator.updateDuration(duration);
    _coordinator.updatePosition(position);
  }

  Future<void> onPlaybackStopped() async {
    await _coordinator.stopPlayback();
  }
}
