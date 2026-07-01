import '../../media/media_kind.dart';
import '../../media/media_library.dart';

const browseGroupingAll = 'all';
const browseGroupingMovies = 'movies';
const browseGroupingShows = 'shows';
const browseGroupingSeasons = 'seasons';
const browseGroupingEpisodes = 'episodes';
const browseGroupingFolders = 'folders';

List<String> libraryBrowseGroupingOptions(MediaLibrary library, {required bool canGroupByFolders}) {
  final kind = library.browseKind;
  if (library.isShared) {
    return const [
      browseGroupingAll,
      browseGroupingMovies,
      browseGroupingShows,
      browseGroupingSeasons,
      browseGroupingEpisodes,
    ];
  }

  return switch (kind) {
    MediaKind.show => [
      browseGroupingShows,
      browseGroupingSeasons,
      browseGroupingEpisodes,
      if (canGroupByFolders) browseGroupingFolders,
    ],
    MediaKind.movie => [browseGroupingMovies, if (canGroupByFolders) browseGroupingFolders],
    MediaKind.mixed => [
      browseGroupingAll,
      browseGroupingShows,
      browseGroupingMovies,
      browseGroupingEpisodes,
      if (canGroupByFolders) browseGroupingFolders,
    ],
    _ => [
      browseGroupingAll,
      browseGroupingShows,
      browseGroupingMovies,
      browseGroupingEpisodes,
      if (canGroupByFolders) browseGroupingFolders,
    ],
  };
}

String defaultLibraryBrowseGrouping(MediaLibrary library) {
  if (library.isShared) return browseGroupingAll;
  return switch (library.browseKind) {
    MediaKind.show => browseGroupingShows,
    MediaKind.movie => browseGroupingMovies,
    MediaKind.mixed => browseGroupingAll,
    _ => browseGroupingAll,
  };
}

String normalizeLibraryBrowseGrouping(MediaLibrary library, String? grouping, {required bool canGroupByFolders}) {
  // Mixed and untyped video libraries default to "all" (movies + shows, no episodes).
  if ((library.browseKind == MediaKind.mixed || library.browseKind == MediaKind.unknown) &&
      (grouping == null || grouping == browseGroupingAll)) {
    return browseGroupingAll;
  }

  final options = libraryBrowseGroupingOptions(library, canGroupByFolders: canGroupByFolders);
  if (grouping != null && options.contains(grouping)) return grouping;

  final fallback = defaultLibraryBrowseGrouping(library);
  return options.contains(fallback) ? fallback : options.first;
}
