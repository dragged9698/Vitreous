/// Time-unit conversions for Emby's wire format.
///
/// Emby reports durations and offsets in "ticks" (100-nanosecond units, a
/// .NET `DateTime.Ticks` legacy) and timestamps as ISO-8601 strings. The app
/// otherwise speaks milliseconds + Unix epoch seconds, so every Emby
/// boundary needs a conversion. Centralised here so the shape is consistent
/// across mappers, the client, and the playback bundle.
library;

const int _ticksPerMs = 10_000;

/// Emby ticks → milliseconds. Returns `null` for non-numeric input.
int? embyTicksToMs(Object? ticks) {
  if (ticks is num) return ticks ~/ _ticksPerMs;
  return null;
}

/// Milliseconds → Emby ticks. Used when reporting playback position back
/// to the server (`PositionTicks`).
int msToEmbyTicks(int ms) => ms * _ticksPerMs;

/// ISO-8601 date string → Unix epoch seconds. Returns `null` for empty,
/// missing, or unparseable input.
int? embyIsoToEpochSeconds(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  return dt.millisecondsSinceEpoch ~/ 1000;
}

/// Truncate a Emby ISO-8601 datetime to `YYYY-MM-DD` so it lines up with
/// Plex's `originallyAvailableAt` shape. Returns `null` for empty input.
String? embyIsoToYmd(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final i = iso.indexOf('T');
  return i > 0 ? iso.substring(0, i) : iso;
}

/// Legacy alias used by metadata edit adapters.
String? jellyfinIsoToYmd(String? iso) => embyIsoToYmd(iso);
