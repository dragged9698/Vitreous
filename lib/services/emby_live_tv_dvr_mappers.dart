import '../models/livetv_program.dart';
import '../models/media_grab_operation.dart';
import '../models/media_subscription.dart';

/// Maps Emby/Jellyfin Live TV timer DTOs to the Plex-shaped models used by
/// the Live TV recordings UI.
class EmbyLiveTvDvrMappers {
  EmbyLiveTvDvrMappers._();

  static int? _epochSec(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    final ms = DateTime.tryParse(raw)?.toUtc().millisecondsSinceEpoch;
    return ms != null ? ms ~/ 1000 : null;
  }

  static List<SubscriptionSetting> recordingSettings({
    int prePaddingMinutes = 0,
    int postPaddingMinutes = 0,
    String keepUntil = 'UntilDeleted',
    bool recordNewOnly = true,
    bool skipEpisodesInLibrary = true,
    int keepUpTo = 5,
    String? channelId,
    bool isSeries = false,
  }) {
    return [
      if (channelId != null)
        SubscriptionSetting(id: 'channelId', value: channelId, hidden: true),
      SubscriptionSetting(
        id: 'prePadding',
        label: 'Pre-padding (minutes)',
        type: 'integer',
        defaultValue: prePaddingMinutes,
        value: prePaddingMinutes,
      ),
      SubscriptionSetting(
        id: 'postPadding',
        label: 'Post-padding (minutes)',
        type: 'integer',
        defaultValue: postPaddingMinutes,
        value: postPaddingMinutes,
      ),
      SubscriptionSetting(
        id: 'keepUntil',
        label: 'Keep until',
        type: 'text',
        defaultValue: keepUntil,
        value: keepUntil,
        enumValues: 'UntilDeleted:I delete it|UntilSpaceNeeded:Space needed|UntilWatched:I watch it',
      ),
      if (isSeries) ...[
        SubscriptionSetting(
          id: 'recordNewOnly',
          label: 'Record new episodes only',
          type: 'bool',
          defaultValue: recordNewOnly,
          value: recordNewOnly,
        ),
        SubscriptionSetting(
          id: 'skipEpisodesInLibrary',
          label: 'Skip episodes already in library',
          type: 'bool',
          defaultValue: skipEpisodesInLibrary,
          value: skipEpisodesInLibrary,
        ),
        SubscriptionSetting(
          id: 'keepUpTo',
          label: 'Episodes to keep',
          type: 'integer',
          defaultValue: keepUpTo,
          value: keepUpTo,
        ),
      ],
    ];
  }

  static List<SubscriptionSetting> settingsFromSeriesTimer(Map<String, dynamic> json) {
    return recordingSettings(
      prePaddingMinutes: ((json['PrePaddingSeconds'] as num?) ?? 0) ~/ 60,
      postPaddingMinutes: ((json['PostPaddingSeconds'] as num?) ?? 0) ~/ 60,
      keepUntil: json['KeepUntil'] as String? ?? 'UntilDeleted',
      recordNewOnly: json['RecordNewOnly'] as bool? ?? true,
      skipEpisodesInLibrary: json['SkipEpisodesInLibrary'] as bool? ?? true,
      keepUpTo: (json['KeepUpTo'] as num?)?.toInt() ?? 5,
      channelId: json['ChannelId'] as String?,
      isSeries: true,
    );
  }

  static List<SubscriptionSetting> settingsFromTimer(Map<String, dynamic> json) {
    return recordingSettings(
      prePaddingMinutes: ((json['PrePaddingSeconds'] as num?) ?? 0) ~/ 60,
      postPaddingMinutes: ((json['PostPaddingSeconds'] as num?) ?? 0) ~/ 60,
      keepUntil: json['KeepUntil'] as String? ?? 'UntilDeleted',
      channelId: json['ChannelId'] as String?,
    );
  }

  static MediaSubscription seriesTimerToSubscription(Map<String, dynamic> json) {
    final id = json['Id'] as String? ?? '';
    return MediaSubscription(
      key: id,
      type: 2,
      title: json['Name'] as String? ?? json['SeriesName'] as String?,
      airingsType: 'Series',
      parameters: json['ProgramId'] as String?,
      settings: settingsFromSeriesTimer(json),
    );
  }

  static MediaSubscription timerToSubscription(Map<String, dynamic> json) {
    final id = json['Id'] as String? ?? '';
    return MediaSubscription(
      key: id,
      type: 4,
      title: json['Name'] as String? ?? json['ProgramName'] as String?,
      airingsType: 'Once',
      parameters: json['ProgramId'] as String?,
      settings: settingsFromTimer(json),
    );
  }

  static Map<String, dynamic> timerMetadata(Map<String, dynamic> json) {
    return {
      'title': json['Name'] ?? json['ProgramName'] ?? '',
      'beginsAt': _epochSec(json['StartDate']),
      'endsAt': _epochSec(json['EndDate']),
      'grandparentTitle': json['SeriesName'],
      'channelIdentifier': json['ChannelId'],
      'channelCallSign': json['ChannelName'],
      'ratingKey': json['ProgramId'],
      'guid': json['ProgramId'],
    };
  }

  static MediaGrabOperation timerToGrab(Map<String, dynamic> json) {
    final id = json['Id'] as String? ?? '';
    return MediaGrabOperation(
      id: id,
      key: id,
      status: json['Status'] as String?,
      metadata: timerMetadata(json),
    );
  }

  static Map<String, dynamic> createTimerBody({
    required String programId,
    required String channelId,
    required String name,
    required Map<String, Object?> prefs,
  }) {
    final prePadding = ((prefs['prePadding'] as num?) ?? 0).toInt();
    final postPadding = ((prefs['postPadding'] as num?) ?? 0).toInt();
    return {
      'ProgramId': programId,
      'ChannelId': channelId,
      'Name': name,
      'PrePaddingSeconds': prePadding * 60,
      'PostPaddingSeconds': postPadding * 60,
      'KeepUntil': prefs['keepUntil'] ?? 'UntilDeleted',
      'Priority': 0,
    };
  }

  static Map<String, dynamic> createSeriesTimerBody({
    required String programId,
    required String channelId,
    required String name,
    required Map<String, Object?> prefs,
  }) {
    final prePadding = ((prefs['prePadding'] as num?) ?? 0).toInt();
    final postPadding = ((prefs['postPadding'] as num?) ?? 0).toInt();
    return {
      'ProgramId': programId,
      'ChannelId': channelId,
      'Name': name,
      'PrePaddingSeconds': prePadding * 60,
      'PostPaddingSeconds': postPadding * 60,
      'KeepUntil': prefs['keepUntil'] ?? 'UntilDeleted',
      'RecordNewOnly': prefs['recordNewOnly'] ?? true,
      'SkipEpisodesInLibrary': prefs['skipEpisodesInLibrary'] ?? true,
      'KeepUpTo': prefs['keepUpTo'] ?? 5,
      'Priority': 0,
    };
  }

  static Map<String, dynamic> updateSeriesTimerBody(
    Map<String, dynamic> existing,
    Map<String, Object?> prefs,
  ) {
    final body = Map<String, dynamic>.from(existing);
    if (prefs.containsKey('prePadding')) {
      body['PrePaddingSeconds'] = ((prefs['prePadding'] as num?) ?? 0).toInt() * 60;
    }
    if (prefs.containsKey('postPadding')) {
      body['PostPaddingSeconds'] = ((prefs['postPadding'] as num?) ?? 0).toInt() * 60;
    }
    if (prefs.containsKey('keepUntil')) body['KeepUntil'] = prefs['keepUntil'];
    if (prefs.containsKey('recordNewOnly')) body['RecordNewOnly'] = prefs['recordNewOnly'];
    if (prefs.containsKey('skipEpisodesInLibrary')) {
      body['SkipEpisodesInLibrary'] = prefs['skipEpisodesInLibrary'];
    }
    if (prefs.containsKey('keepUpTo')) body['KeepUpTo'] = prefs['keepUpTo'];
    return body;
  }

  static Map<String, dynamic> updateTimerBody(Map<String, dynamic> existing, Map<String, Object?> prefs) {
    final body = Map<String, dynamic>.from(existing);
    if (prefs.containsKey('prePadding')) {
      body['PrePaddingSeconds'] = ((prefs['prePadding'] as num?) ?? 0).toInt() * 60;
    }
    if (prefs.containsKey('postPadding')) {
      body['PostPaddingSeconds'] = ((prefs['postPadding'] as num?) ?? 0).toInt() * 60;
    }
    if (prefs.containsKey('keepUntil')) body['KeepUntil'] = prefs['keepUntil'];
    return body;
  }

  static List<MediaSubscription> subscriptionTemplateEntries({
    required String programId,
    required String? channelId,
    required String? title,
    required bool hasSeries,
  }) {
    final settingsOnce = recordingSettings(channelId: channelId);
    final entries = <MediaSubscription>[
      MediaSubscription(
        key: '',
        type: 4,
        title: title,
        airingsType: 'Once',
        selected: !hasSeries,
        parameters: programId,
        settings: settingsOnce,
      ),
    ];
    if (hasSeries) {
      entries.add(
        MediaSubscription(
          key: '',
          type: 2,
          title: title,
          airingsType: 'Series',
          selected: true,
          parameters: programId,
          settings: recordingSettings(channelId: channelId, isSeries: true),
        ),
      );
    }
    return entries;
  }

  static LiveTvProgram? programFromItemJson(Map<String, dynamic> json) {
    try {
      return LiveTvProgram(
        key: json['Id'] as String?,
        ratingKey: json['Id'] as String?,
        guid: json['Id'] as String?,
        title: json['Name'] as String? ?? '',
        channelIdentifier: json['ChannelId'] as String?,
        grandparentTitle: json['SeriesName'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
