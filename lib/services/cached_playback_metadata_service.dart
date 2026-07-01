import 'dart:convert';
import '../media/ids.dart';

import 'package:drift/drift.dart';

import '../media/media_backend.dart';
import '../media/media_source_info.dart';
import '../utils/app_logger.dart';
import 'api_cache.dart';
import 'emby_api_cache.dart';
import 'emby_media_info_mapper.dart';

class CachedPlaybackMetadataService {
  const CachedPlaybackMetadataService._();

  static Future<MediaSourceInfo?> fetchMediaSourceInfo({
    required MediaBackend backend,
    required String cacheServerId,
    required String itemId,
    int mediaIndex = 0,
  }) async {
    if (backend != MediaBackend.emby) return null;
    try {
      return _fetchEmbyMediaSourceInfo(cacheServerId, itemId, mediaIndex: mediaIndex);
    } catch (e) {
      appLogger.d('Cached media source info unavailable for $cacheServerId:$itemId', error: e);
      return null;
    }
  }

  static Future<PlaybackExtras?> fetchPlaybackExtras({
    required MediaBackend backend,
    required String cacheServerId,
    required String itemId,
    String? introPattern,
    String? creditsPattern,
    bool forceChapterFallback = false,
  }) async {
    if (backend != MediaBackend.emby) return null;
    try {
      return _fetchEmbyPlaybackExtras(
        cacheServerId,
        itemId,
        introPattern: introPattern,
        creditsPattern: creditsPattern,
        forceChapterFallback: forceChapterFallback,
      );
    } catch (e) {
      appLogger.d('Cached playback extras unavailable for $cacheServerId:$itemId', error: e);
      return null;
    }
  }

  static Future<MediaSourceInfo?> _fetchEmbyMediaSourceInfo(
    String cacheServerId,
    String itemId, {
    required int mediaIndex,
  }) async {
    final raw = await _embyRawItem(cacheServerId, itemId);
    final sources = raw['MediaSources'];
    if (sources is! List || sources.isEmpty) return null;
    final selected = mediaIndex >= 0 && mediaIndex < sources.length ? sources[mediaIndex] : sources.first;
    if (selected is! Map<String, dynamic>) return null;
    return embyMediaSourceToMediaSourceInfo(selected, chapters: raw['Chapters'], trickplay: raw['Trickplay']);
  }

  static Future<PlaybackExtras?> _fetchEmbyPlaybackExtras(
    String cacheServerId,
    String itemId, {
    String? introPattern,
    String? creditsPattern,
    bool forceChapterFallback = false,
  }) async {
    final raw = await _embyRawItem(cacheServerId, itemId);
    final markers = await _embyMediaSegmentMarkers(cacheServerId, itemId);
    return embyPlaybackExtrasFromRaw(
      raw,
      itemId,
      introPattern: introPattern,
      creditsPattern: creditsPattern,
      forceChapterFallback: forceChapterFallback,
      markers: markers,
    );
  }

  static Future<List<MediaMarker>> _embyMediaSegmentMarkers(String cacheServerId, String itemId) async {
    try {
      final raw = await ApiCache.forBackend(
        MediaBackend.emby,
      ).get(ServerId(cacheServerId), EmbyApiCache.mediaSegmentsEndpoint(itemId));
      return embyMediaSegmentsToMarkers(raw);
    } catch (e) {
      appLogger.d('Cached Emby media segments unavailable for $cacheServerId:$itemId', error: e);
      return const [];
    }
  }

  static Future<Map<String, dynamic>> _embyRawItem(String cacheServerId, String itemId) async {
    final cache = ApiCache.forBackend(MediaBackend.emby);
    final scopedPrefix = cacheServerId.contains('/') ? null : '$cacheServerId/%:/Users/%/Items/$itemId';
    final rows =
        await (cache.database.select(cache.database.apiCache)..where(
              (t) =>
                  t.cacheKey.like('$cacheServerId:/Users/%/Items/$itemId') |
                  (scopedPrefix == null ? const Constant(false) : t.cacheKey.like(scopedPrefix)),
            ))
            .get();
    if (rows.isEmpty) throw StateError('No Emby cache row for $cacheServerId:$itemId');
    return jsonDecode(rows.first.data) as Map<String, dynamic>;
  }
}
