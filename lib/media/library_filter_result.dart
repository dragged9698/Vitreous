import '../i18n/strings.g.dart';
import 'media_filter.dart';

/// Combined filter listing result. Plex returns categories with no values
/// pre-loaded; Jellyfin pre-populates [cachedValues] so the FiltersBottomSheet
/// avoids a second round-trip per category.
class LibraryFilterResult {
  final List<MediaFilter> filters;
  final Map<String, List<MediaFilterValue>> cachedValues;

  const LibraryFilterResult({required this.filters, required this.cachedValues});

  static const empty = LibraryFilterResult(filters: [], cachedValues: {});
}

/// Parse `/Items/Filters` or `/Items/Filters2` list entries. Legacy filters
/// return plain strings; Filters2 returns `{Name, Id}` objects for genres.
List<String> parseItemsFilterStringList(Object? raw) {
  if (raw is! List) return const [];
  final values = <String>[];
  for (final entry in raw) {
    if (entry is String && entry.isNotEmpty) {
      values.add(entry);
      continue;
    }
    if (entry is Map) {
      final name = entry['Name'] ?? entry['name'];
      if (name is String && name.isNotEmpty) values.add(name);
    }
  }
  return values;
}

List<String> parseItemsFilterYears(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<num>().map((y) => y.toInt().toString()).toList();
}

/// Build the shared unwatched + genre/year/rating/tag filter list from an
/// Emby/Jellyfin `/Items/Filters` payload.
LibraryFilterResult buildItemsApiFilterResult({
  required Map<String, dynamic>? data,
  required String keyPrefix,
}) {
  final filters = <MediaFilter>[
    MediaFilter(
      filter: 'unwatched',
      filterType: 'boolean',
      key: '$keyPrefix:unwatched',
      title: t.libraries.filterCategories.unwatched,
      type: 'filter',
    ),
  ];
  if (data == null) return LibraryFilterResult(filters: filters, cachedValues: const {});

  final raw = <String, List<String>>{
    'genre': parseItemsFilterStringList(data['Genres'] ?? data['genres']),
    'contentRating': parseItemsFilterStringList(data['OfficialRatings'] ?? data['officialRatings']),
    'tag': parseItemsFilterStringList(data['Tags'] ?? data['tags']),
    'year': parseItemsFilterYears(data['Years'] ?? data['years']),
  };

  const order = ['genre', 'year', 'contentRating', 'tag'];
  final titles = {
    'genre': t.libraries.filterCategories.genre,
    'year': t.libraries.filterCategories.year,
    'contentRating': t.libraries.filterCategories.contentRating,
    'tag': t.libraries.filterCategories.tag,
  };
  final values = <String, List<MediaFilterValue>>{};
  for (final key in order) {
    final entries = raw[key];
    if (entries == null || entries.isEmpty) continue;
    filters.add(
      MediaFilter(filter: key, filterType: 'string', key: '$keyPrefix:$key', title: titles[key] ?? key, type: 'filter'),
    );
    final sorted = List<String>.from(entries);
    if (key == 'year') {
      sorted.sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    } else {
      sorted.sort();
    }
    values[key] = sorted.map((v) => MediaFilterValue(key: v, title: v)).toList();
  }
  return LibraryFilterResult(filters: filters, cachedValues: values);
}
