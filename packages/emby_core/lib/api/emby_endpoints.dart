/// Centralized Emby REST endpoint path templates.
abstract final class EmbyEndpoints {
  static const systemInfoPublic = '/System/Info/Public';
  static const authenticateByName = '/Users/AuthenticateByName';
  static const sessionsLogout = '/Sessions/Logout';
  static const usersPublic = '/Users/Public';

  static String userViews(String userId) => '/Users/$userId/Views';
  static String userItems(String userId) => '/Users/$userId/Items';
  static String userItem(String userId, String itemId) => '/Users/$userId/Items/$itemId';
  static String itemPlaybackInfo(String itemId) => '/Items/$itemId/PlaybackInfo';
  static String videoStream(String itemId) => '/Videos/$itemId/stream';
  static String audioStream(String itemId) => '/Audio/$itemId/stream';
  static String itemFile(String itemId) => '/Items/$itemId/File';

  static const sessionsPlaying = '/Sessions/Playing';
  static const sessionsPlayingProgress = '/Sessions/Playing/Progress';
  static const sessionsPlayingStopped = '/Sessions/Playing/Stopped';

  static String playingItem(String userId, String itemId) => '/Users/$userId/PlayingItems/$itemId';
  static String playingItemProgress(String userId, String itemId) =>
      '/Users/$userId/PlayingItems/$itemId/Progress';

  static String showSeasons(String seriesId) => '/Shows/$seriesId/Seasons';
  static String showEpisodes(String seriesId) => '/Shows/$seriesId/Episodes';
  static const showsNextUp = '/Shows/NextUp';
  static const moviesRecommendations = '/Movies/Recommendations';
}
