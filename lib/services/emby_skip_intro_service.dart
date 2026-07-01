/// Intro/credits window derived from Emby chapter metadata.
class IntroSkipRange {
  const IntroSkipRange({required this.start, required this.end});

  final Duration start;
  final Duration end;
}

/// Parses Emby `Chapters` arrays for intro/credits marker windows.
class EmbySkipIntroService {
  const EmbySkipIntroService._();

  static IntroSkipRange? parseIntroFromChapters(List<dynamic>? chapters) {
    if (chapters == null) return null;
    for (final raw in chapters) {
      if (raw is! Map) continue;
      final map = raw.cast<String, dynamic>();
      final name = (map['Name'] as String? ?? '').toLowerCase();
      final marker = (map['MarkerType'] as String? ?? '').toLowerCase();
      if (!name.contains('intro') && !marker.contains('intro')) continue;

      final startTicks = map['StartPositionTicks'] as int?;
      final endTicks = map['EndPositionTicks'] as int?;
      if (startTicks == null || endTicks == null || endTicks <= startTicks) continue;

      return IntroSkipRange(
        start: Duration(microseconds: startTicks ~/ 10),
        end: Duration(microseconds: endTicks ~/ 10),
      );
    }
    return null;
  }
}
