import 'package:emby_core/models/base_item_dto.dart';

import '../media/ids.dart';
import '../media/media_backend.dart';
import '../media/media_item.dart';
import '../media/media_kind.dart';

/// Maps [BaseItemDto] from `emby_core` into Vitreous neutral [MediaItem] types.
class EmbyDtoMappers {
  const EmbyDtoMappers._();

  static MediaItem toMediaItem(BaseItemDto dto, {required ServerId serverId}) {
    return MediaItem(
      id: dto.id ?? '',
      backend: MediaBackend.emby,
      kind: _kindFromType(dto.type),
      title: dto.name,
      summary: dto.overview,
      year: dto.productionYear,
      parentId: dto.parentId,
      index: dto.indexNumber,
      parentIndex: dto.parentIndexNumber,
      serverId: serverId,
    );
  }

  static MediaKind _kindFromType(String? type) => switch (type) {
        'Movie' => MediaKind.movie,
        'Series' => MediaKind.show,
        'Season' => MediaKind.season,
        'Episode' => MediaKind.episode,
        'MusicAlbum' => MediaKind.album,
        'Audio' => MediaKind.track,
        'MusicArtist' => MediaKind.artist,
        'Photo' => MediaKind.photo,
        'BoxSet' => MediaKind.collection,
        _ => MediaKind.unknown,
      };
}
