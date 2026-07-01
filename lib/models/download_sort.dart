/// Sort order for completed download grids.
enum DownloadSortOrder {
  titleAsc,
  titleDesc,
  dateAddedDesc,
  dateAddedAsc;

  String get id => name;

  static DownloadSortOrder fromId(String? id) {
    return DownloadSortOrder.values.firstWhere((m) => m.id == id, orElse: () => DownloadSortOrder.titleAsc);
  }
}

/// Filter for completed download grids.
enum DownloadFilterMode {
  all,
  unwatched,
  watched;

  String get id => name;

  static DownloadFilterMode fromId(String? id) {
    return DownloadFilterMode.values.firstWhere((m) => m.id == id, orElse: () => DownloadFilterMode.all);
  }
}
