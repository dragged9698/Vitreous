/// Chapter marker from Emby item metadata (intro/credits detection).
class ChapterInfo {
  const ChapterInfo({
    this.startPositionTicks,
    this.endPositionTicks,
    this.name,
    this.markerType,
  });

  factory ChapterInfo.fromJson(Map<String, dynamic> json) => ChapterInfo(
        startPositionTicks: json['StartPositionTicks'] as int?,
        endPositionTicks: json['EndPositionTicks'] as int?,
        name: json['Name'] as String?,
        markerType: json['MarkerType'] as String?,
      );

  final int? startPositionTicks;
  final int? endPositionTicks;
  final String? name;
  final String? markerType;

  Duration? get start => startPositionTicks == null
      ? null
      : Duration(microseconds: startPositionTicks! ~/ 10);
  Duration? get end =>
      endPositionTicks == null ? null : Duration(microseconds: endPositionTicks! ~/ 10);
}
