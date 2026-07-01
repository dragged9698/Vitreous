import 'package:emby_core/api/emby_api_service.dart';
import 'package:emby_core/models/base_item_dto.dart';
import 'package:emby_core/models/playback_info.dart';
import 'package:emby_core/models/query_result.dart';

/// Read-only media operations backed by [EmbyApiService].
abstract interface class MediaRepository {
  Future<QueryResult<BaseItemDto>> getViews();
  Future<QueryResult<BaseItemDto>> getItems({String? parentId, int? limit});
  Future<BaseItemDto> getItemDetail(String itemId, {String? fields});
  Future<PlaybackInfo> getPlaybackInfo(String itemId);
}

class EmbyMediaRepository implements MediaRepository {
  EmbyMediaRepository(this._api);

  final EmbyApiService _api;

  @override
  Future<QueryResult<BaseItemDto>> getViews() => _api.getViews();

  @override
  Future<QueryResult<BaseItemDto>> getItems({String? parentId, int? limit}) =>
      _api.getItems(parentId: parentId, limit: limit);

  @override
  Future<BaseItemDto> getItemDetail(String itemId, {String? fields}) =>
      _api.getItemDetail(itemId, fields: fields);

  @override
  Future<PlaybackInfo> getPlaybackInfo(String itemId) => _api.getPlaybackInfo(itemId);
}
