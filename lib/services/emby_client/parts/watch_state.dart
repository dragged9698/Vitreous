part of '../../emby_client.dart';

mixin _EmbyWatchStateMethods on MediaServerCacheMixin {
  EmbyConnection get connection;
  FailoverHttpClient get _http;

  @override
  Future<void> markWatched(MediaItem item) async {
    final response = await _http.post(
      '/UserPlayedItems/${_segment(item.id)}',
      queryParameters: {'userId': connection.userId},
    );
    throwIfHttpError(response);
  }

  @override
  Future<void> markUnwatched(MediaItem item) async {
    final response = await _http.delete(
      '/UserPlayedItems/${_segment(item.id)}',
      queryParameters: {'userId': connection.userId},
    );
    throwIfHttpError(response);
  }

  @override
  Future<void> removeFromContinueWatching(MediaItem item) async {
    throw UnsupportedError('Emby does not support removing items from Continue Watching.');
  }

  @override
  Future<void> setFavorite(MediaItem item, bool isFavorite) async {
    final path = '/Users/${_segment(connection.userId)}/FavoriteItems/${_segment(item.id)}';
    final response = isFavorite ? await _http.post(path) : await _http.delete(path);
    throwIfHttpError(response);
  }

  @override
  Future<void> rate(MediaItem item, double rating) async {
    // Emby routes ratings under /Users/{userId}/Items/{itemId}/Rating with a
    // JSON body — not Jellyfin's /UserItems/{id}/Rating query-param form.
    // Lossy mapping — Emby only stores a binary like/dislike. Treat
    // a negative input as "clear the rating" (DELETE), >= 6/10 as a like
    // (POST Likes=true), and the rest as a dislike (POST Likes=false).
    final path = '/Users/${_segment(connection.userId)}/Items/${_segment(item.id)}/Rating';
    final response = rating < 0
        ? await _http.delete(path)
        : await _http.post(path, body: {'Likes': rating >= 6.0});
    throwIfHttpError(response);
  }
}
