part of '../../emby_client.dart';

mixin _EmbyLiveTvMethods on MediaServerCacheMixin {
  EmbyConnection get connection;
  FailoverHttpClient get _http;
  String? _absolutizeImagePath(String? path);
  Future<List<Map<String, dynamic>>> _safeFetchItemsArray(
    String path,
    Map<String, dynamic> queryParameters, {
    // ignore: unused_element_parameter
    _HubRetryPolicy? retry,
  });

  /// Returns `true` when this server has Live TV configured (channels
  /// available). Probes `/LiveTv/Channels?limit=1`. Used by [MultiServerProvider]
  /// to gate the Live TV menu.
  Future<bool> hasLiveTv() async {
    try {
      final response = await _http.get(
        '/LiveTv/Channels',
        queryParameters: {'limit': '1', 'userId': connection.userId},
      );
      if (response.statusCode != 200) return false;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final total = data['TotalRecordCount'];
        if (total is int) return total > 0;
        final items = data['Items'];
        if (items is List) return items.isNotEmpty;
      }
      return false;
    } catch (e) {
      appLogger.d('Emby Live TV probe failed', error: e);
      return false;
    }
  }

  /// Fetch the user's Live TV channel list. Each `BaseItemDto` of type
  /// `TvChannel` is mapped to a [LiveTvChannel].
  Future<List<LiveTvChannel>> fetchLiveTvChannels() async {
    final items = await _safeFetchItemsArray('/LiveTv/Channels', {
      'userId': connection.userId,
      'enableImages': 'true',
      'enableUserData': 'true',
      'sortBy': 'SortName',
      'sortOrder': 'Ascending',
    });
    return items.map(_channelFromJson).toList();
  }

  /// EPG / programs grid. [channelIds] scopes to specific channels (when
  /// empty, the server returns programs across all channels). [beginsAt] /
  /// [endsAt] are epoch seconds and bound the visible window — programs that
  /// overlap the window are included (not only those that start inside it).
  Future<List<LiveTvProgram>> fetchLiveTvPrograms({
    List<String> channelIds = const [],
    int? beginsAt,
    int? endsAt,
  }) async {
    String? isoUtc(int? epoch) {
      if (epoch == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true).toIso8601String();
    }

    final params = <String, dynamic>{
      'UserId': connection.userId,
      'EnableImages': 'true',
      'EnableTotalRecordCount': 'true',
      'SortBy': 'StartDate',
      'SortOrder': 'Ascending',
      if (channelIds.isNotEmpty) 'ChannelIds': channelIds.join(','),
      // Overlap filter: EndDate > beginsAt AND StartDate < endsAt
      if (beginsAt != null) 'MinEndDate': isoUtc(beginsAt),
      if (endsAt != null) 'MaxStartDate': isoUtc(endsAt),
    };

    final items = await _fetchLiveTvProgramsPage(params);
    return items.map(_programFromJson).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchLiveTvProgramsPage(Map<String, dynamic> baseParams) async {
    final all = <Map<String, dynamic>>[];
    var startIndex = 0;
    const pageSize = 1000;

    while (true) {
      final params = {...baseParams, 'StartIndex': '$startIndex', 'Limit': '$pageSize'};
      final response = await _http.get('/LiveTv/Programs', queryParameters: params);
      throwIfHttpError(response);
      final data = response.data;
      final page = _itemsArray(data);
      all.addAll(page);

      final total = data is Map<String, dynamic>
          ? flexibleInt(data['TotalRecordCount'] ?? data['totalRecordCount'])
          : null;
      if (page.isEmpty || page.length < pageSize || (total != null && all.length >= total)) break;
      startIndex += page.length;
    }

    appLogger.d('Emby Live TV programs: ${all.length} items');
    return all;
  }

  LiveTvProgram _programFromJson(Map<String, dynamic> json) {
    final id = jsonStringField(json, 'Id');
    int? toEpochSec(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) {
        if (raw.isEmpty) return null;
        final ms = DateTime.tryParse(raw)?.toUtc().millisecondsSinceEpoch;
        return ms != null ? ms ~/ 1000 : null;
      }
      if (raw is DateTime) return raw.toUtc().millisecondsSinceEpoch ~/ 1000;
      if (raw is num) return raw.toInt();
      return null;
    }

    final tags = json['ImageTags'] ?? json['imageTags'];
    String? primaryTag;
    if (tags is Map<String, dynamic>) {
      primaryTag = jsonStringField(tags, 'Primary');
    }
    final thumbPath = (id != null && primaryTag != null)
        ? _absolutizeImagePath('/Items/${_segment(id)}/Images/Primary?tag=${Uri.encodeComponent(primaryTag)}')
        : null;
    return LiveTvProgram(
      key: id,
      ratingKey: id,
      guid: id,
      title: jsonStringField(json, 'Name') ?? t.liveTv.unknownProgram,
      summary: jsonStringField(json, 'Overview'),
      type: 'episode',
      year: flexibleInt(json['ProductionYear'] ?? json['productionYear']),
      beginsAt: toEpochSec(json['StartDate'] ?? json['startDate'] ?? jsonStringField(json, 'StartDate')),
      endsAt: toEpochSec(json['EndDate'] ?? json['endDate'] ?? jsonStringField(json, 'EndDate')),
      grandparentTitle: jsonStringField(json, 'SeriesName'),
      parentTitle: jsonStringField(json, 'SeasonName'),
      index: flexibleInt(json['IndexNumber'] ?? json['indexNumber']),
      parentIndex: flexibleInt(json['ParentIndexNumber'] ?? json['parentIndexNumber']),
      thumb: thumbPath,
      art: null,
      channelIdentifier: jsonStringField(json, 'ChannelId') ?? jsonStringField(json, 'ParentId'),
      channelCallSign: jsonStringField(json, 'ChannelCallSign') ?? jsonStringField(json, 'ChannelName'),
      live: flexibleBoolNullable(json['IsLive'] ?? json['isLive']),
      premiere: flexibleBoolNullable(json['IsPremiere'] ?? json['isPremiere']),
      serverId: serverId,
      serverName: serverName,
    );
  }

  LiveTvChannel _channelFromJson(Map<String, dynamic> json) {
    final id = jsonStringField(json, 'Id') ?? '';
    final name = jsonStringField(json, 'Name');
    final number = jsonStringField(json, 'Number') ?? jsonStringField(json, 'ChannelNumber');
    final tags = json['ImageTags'] ?? json['imageTags'];
    String? primaryTag;
    if (tags is Map<String, dynamic>) {
      primaryTag = jsonStringField(tags, 'Primary');
    }
    final thumbPath = primaryTag != null
        ? _absolutizeImagePath('/Items/${_segment(id)}/Images/Primary?tag=${Uri.encodeComponent(primaryTag)}')
        : null;
    return LiveTvChannel(
      key: id,
      identifier: id,
      callSign: jsonStringField(json, 'CallSign'),
      title: name,
      thumb: thumbPath,
      art: null,
      number: number,
      hd: false,
      lineup: null,
      slug: null,
      drm: null,
      serverId: serverId,
      serverName: serverName,
    );
  }

  @override
  LiveTvSupport get liveTv => _EmbyLiveTvSupport(this as EmbyClient);

  /// Toggle the per-user `IsFavorite` flag for [itemId]. Used by the live-TV
  /// favorite-channel adapter; works on any Emby item.
  Future<void> _setItemFavorite(String itemId, bool isFavorite) async {
    final path = '/Users/${_segment(connection.userId)}/FavoriteItems/${_segment(itemId)}';
    final response = isFavorite ? await _http.post(path) : await _http.delete(path);
    throwIfHttpError(response);
  }

  List<Map<String, dynamic>> _timerItems(dynamic data) {
    if (data is Map<String, dynamic>) {
      final items = data['Items'];
      if (items is List) {
        return [for (final item in items) if (item is Map<String, dynamic>) item];
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>?> _fetchTimerDto(String timerId, {required bool series}) async {
    final path = series ? '/LiveTv/SeriesTimers/${_segment(timerId)}' : '/LiveTv/Timers/${_segment(timerId)}';
    final response = await _http.get(path);
    if (response.statusCode == 404) return null;
    throwIfHttpError(response);
    return response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
  }

  Future<List<SubscriptionTemplate>> _getSubscriptionTemplate(String programId) async {
    final response = await _http.get('/Users/${_segment(connection.userId)}/Items/${_segment(programId)}');
    throwIfHttpError(response);
    final json = response.data;
    if (json is! Map<String, dynamic>) return const [];

    final channelId = json['ChannelId'] as String?;
    final title = json['Name'] as String?;
    final hasSeries = (json['SeriesId'] as String?)?.isNotEmpty == true || json['SeriesName'] != null;

    return [
      SubscriptionTemplate(
        subscriptions: EmbyLiveTvDvrMappers.subscriptionTemplateEntries(
          programId: programId,
          channelId: channelId,
          title: title,
          hasSeries: hasSeries,
        ),
      ),
    ];
  }

  Future<List<MediaSubscription>> _fetchRecordingRules() async {
    final response = await _http.get('/LiveTv/SeriesTimers');
    throwIfHttpError(response);
    return _timerItems(response.data).map(EmbyLiveTvDvrMappers.seriesTimerToSubscription).toList();
  }

  Future<List<MediaGrabOperation>> _fetchScheduledRecordings() async {
    final response = await _http.get('/LiveTv/Timers');
    throwIfHttpError(response);
    return _timerItems(response.data).map(EmbyLiveTvDvrMappers.timerToGrab).toList();
  }

  Future<MediaSubscription?> _createRecordingRule(MediaSubscriptionCreateRequest request) async {
    final programId = request.parameters;
    if (programId == null || programId.isEmpty) return null;

    final prefs = request.prefs;
    final channelId = prefs['channelId'] as String?;
    if (channelId == null || channelId.isEmpty) return null;

    final isSeries = request.type == 2;
    var title = programId;
    try {
      final itemResponse = await _http.get('/Users/${_segment(connection.userId)}/Items/${_segment(programId)}');
      if (itemResponse.statusCode == 200 && itemResponse.data is Map<String, dynamic>) {
        title = (itemResponse.data as Map<String, dynamic>)['Name'] as String? ?? programId;
      }
    } catch (e) {
      appLogger.d('Failed to fetch program title for recording', error: e);
    }

    if (isSeries) {
      final body = EmbyLiveTvDvrMappers.createSeriesTimerBody(
        programId: programId,
        channelId: channelId,
        name: title,
        prefs: prefs,
      );
      final response = await _http.post('/LiveTv/SeriesTimers', body: body);
      throwIfHttpError(response);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return EmbyLiveTvDvrMappers.seriesTimerToSubscription(data);
      }
      return null;
    }

    final body = EmbyLiveTvDvrMappers.createTimerBody(
      programId: programId,
      channelId: channelId,
      name: title,
      prefs: prefs,
    );
    final response = await _http.post('/LiveTv/Timers', body: body);
    throwIfHttpError(response);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return EmbyLiveTvDvrMappers.timerToSubscription(data);
    }
    return null;
  }

  Future<MediaSubscription?> _updateRecordingRule(String subscriptionId, Map<String, Object?> prefs) async {
    final series = await _fetchTimerDto(subscriptionId, series: true);
    if (series != null) {
      final body = EmbyLiveTvDvrMappers.updateSeriesTimerBody(series, prefs);
      final response = await _http.post('/LiveTv/SeriesTimers/${_segment(subscriptionId)}', body: body);
      throwIfHttpError(response);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return EmbyLiveTvDvrMappers.seriesTimerToSubscription(data);
      }
      return EmbyLiveTvDvrMappers.seriesTimerToSubscription(body);
    }

    final timer = await _fetchTimerDto(subscriptionId, series: false);
    if (timer == null) return null;
    final body = EmbyLiveTvDvrMappers.updateTimerBody(timer, prefs);
    final response = await _http.post('/LiveTv/Timers/${_segment(subscriptionId)}', body: body);
    throwIfHttpError(response);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return EmbyLiveTvDvrMappers.timerToSubscription(data);
    }
    return EmbyLiveTvDvrMappers.timerToSubscription(body);
  }

  Future<void> _deleteRecordingRule(String subscriptionId) async {
    var response = await _http.delete('/LiveTv/SeriesTimers/${_segment(subscriptionId)}');
    if (response.statusCode == 404) {
      response = await _http.delete('/LiveTv/Timers/${_segment(subscriptionId)}');
    }
    throwIfHttpError(response);
  }

  Future<void> _cancelGrab(String operationId) async {
    final response = await _http.delete('/LiveTv/Timers/${_segment(operationId)}');
    throwIfHttpError(response);
  }
}

/// Adapter from [LiveTvSupport] to Emby channel/program helpers.
class _EmbyLiveTvSupport implements LiveTvSupport {
  final EmbyClient _client;
  _EmbyLiveTvSupport(this._client);

  Future<T> _unsupported<T>() async => throw UnimplementedError('Emby DVR recording API is not implemented');

  Never _unsupportedSync() => throw UnimplementedError('Emby DVR recording API is not implemented');

  @override
  Future<bool> isAvailable() => _client.hasLiveTv();

  @override
  Future<List<LiveTvDvr>> fetchDvrs() async => const [];

  @override
  Future<List<LiveTvChannel>> fetchChannels({String? lineup}) => _client.fetchLiveTvChannels();

  @override
  Future<List<LiveTvProgram>> fetchSchedule({DateTime? from, DateTime? to}) {
    int? toEpoch(DateTime? dt) => dt == null ? null : dt.millisecondsSinceEpoch ~/ 1000;
    return _client.fetchLiveTvPrograms(beginsAt: toEpoch(from), endsAt: toEpoch(to));
  }

  @override
  Future<LiveTvStreamResolution?> resolveStreamUrl(
    String channelKey, {
    String? dvrKey,
    bool directStream = true,
    bool directStreamAudio = true,
  }) async {
    final info = await _client.getPlaybackInfo(
      channelKey,
      autoOpenLiveStream: true,
      enableDirectPlay: directStream,
      enableDirectStream: directStream,
      enableTranscoding: !directStream,
      allowVideoStreamCopy: directStream,
      allowAudioStreamCopy: directStreamAudio,
    );
    final sources = info?['MediaSources'];
    final source = sources is List && sources.isNotEmpty && sources.first is Map<String, dynamic>
        ? sources.first as Map<String, dynamic>
        : null;
    if (source == null) return null;

    String? nonEmptyString(dynamic raw) => raw is String && raw.isNotEmpty ? raw : null;

    var playSessionId = nonEmptyString(info?['PlaySessionId']);
    final transcodingUrl = nonEmptyString(source['TranscodingUrl']);
    final directStreamUrl = nonEmptyString(source['DirectStreamUrl']);
    final rawUrl = !directStream && transcodingUrl != null
        ? transcodingUrl
        : (directStreamUrl ?? transcodingUrl);
    final url = rawUrl != null
        ? _client._withApiKey(rawUrl)
        : _client.buildDirectStreamUrl(
            channelKey,
            container: nonEmptyString(source['Container']),
            mediaSourceId: nonEmptyString(source['Id']),
            playSessionId: playSessionId,
            liveStreamId: nonEmptyString(source['LiveStreamId']),
            staticStream: directStream,
          );
    playSessionId ??= Uri.tryParse(url)?.queryParameters['PlaySessionId'];
    return LiveTvStreamResolution(url: url, playSessionId: playSessionId);
  }

  @override
  Future<LiveTvPlaybackSession?> startPlayback(String channelKey, {String? dvrKey}) async {
    final resolution = await resolveStreamUrl(channelKey, dvrKey: dvrKey);
    if (resolution == null) return null;
    return _EmbyLiveTvPlaybackSession(_client, channelKey, resolution);
  }

  /// SharedPreferences key for the locally-persisted favorite-channel list.
  /// Keyed by the compound connection id (`{machineId}/{userId}`) so two
  /// Emby users on the same server don't share favorites.
  String get _favoritesPrefsKey => 'emby_fav_channels:${_client.connection.id}';

  /// Legacy bare-machineId key, kept for one-shot migration.
  String get _legacyFavoritesPrefsKey => 'emby_fav_channels:${_client.serverId}';

  @override
  Future<String> buildFavoriteChannelSource({String? lineup}) async => 'server://${_client.serverId}/emby';

  @override
  String get favoriteStoreKey => 'emby:${_client.connection.id}';

  @override
  FavoriteChannelPersistenceMode get favoritePersistenceMode => FavoriteChannelPersistenceMode.serverSlice;

  /// Local list is the source of truth (preserves order + display fields).
  /// Server-side `IsFavorite` is mirrored on writes via [setFavoriteChannels].
  @override
  Future<List<FavoriteChannel>> fetchFavoriteChannels() async {
    try {
      return await _client._favoritesRepository.read(key: _favoritesPrefsKey, legacyKey: _legacyFavoritesPrefsKey);
    } catch (e) {
      appLogger.e('Failed to read Emby favorite channels', error: e);
      return const [];
    }
  }

  @override
  Future<void> setFavoriteChannels(List<FavoriteChannel> channels) async {
    try {
      final previous = await fetchFavoriteChannels();
      final previousIds = previous.map((c) => c.id).toSet();
      final newIds = channels.map((c) => c.id).toSet();

      for (final id in newIds.difference(previousIds)) {
        try {
          await _client._setItemFavorite(id, true);
        } catch (e) {
          appLogger.w('Failed to mark Emby channel $id favorite: $e');
        }
      }
      for (final id in previousIds.difference(newIds)) {
        try {
          await _client._setItemFavorite(id, false);
        } catch (e) {
          appLogger.w('Failed to unmark Emby channel $id favorite: $e');
        }
      }

      await _client._favoritesRepository.write(_favoritesPrefsKey, channels);
    } catch (e) {
      appLogger.e('Failed to save Emby favorite channels', error: e);
    }
  }

  @override
  Future<LiveTvServerStatus> fetchLiveTvServerStatus() async {
    final available = await _client.hasLiveTv();
    return LiveTvServerStatus(liveTvCount: available ? 1 : 0, allowTuners: true);
  }

  @override
  Future<LiveTvDvr?> fetchDvr(String dvrId) => _unsupported();

  @override
  Future<LiveTvActivityResult<LiveTvDvr?>> createDvr({
    required List<String> devices,
    required List<String> lineups,
    String? language,
    String? country,
    String? postalCode,
  }) => _unsupported();

  @override
  Future<void> deleteDvr(String dvrId) => _unsupported();

  @override
  Future<void> updateDvrPrefs(String dvrId, Map<String, Object?> prefs) => _unsupported();

  @override
  Future<void> attachDeviceToDvr(String dvrId, String deviceId) => _unsupported();

  @override
  Future<void> detachDeviceFromDvr(String dvrId, String deviceId) => _unsupported();

  @override
  Future<void> addLineupToDvr(String dvrId, String lineupUri) => _unsupported();

  @override
  Future<void> removeLineupFromDvr(String dvrId, String lineupUri) => _unsupported();

  @override
  Future<LiveTvActivityResult<void>> reloadGuide(String dvrId) => _unsupported();

  @override
  Future<void> cancelGuideReload(String dvrId) => _unsupported();

  @override
  Future<List<MediaGrabber>> fetchGrabbers({String? protocol}) => _unsupported();

  @override
  Future<List<MediaGrabberDevice>> fetchGrabberDevices() => _unsupported();

  @override
  Future<LiveTvActivityResult<List<MediaGrabberDevice>>> discoverGrabberDevices() => _unsupported();

  @override
  Future<MediaGrabberDevice?> fetchGrabberDevice(String deviceId) => _unsupported();

  @override
  Future<MediaGrabberDevice?> addGrabberDevice(String uri, {String? grabberId}) => _unsupported();

  @override
  Future<void> updateGrabberDevice(String deviceId, {bool? enabled, String? title}) => _unsupported();

  @override
  Future<void> deleteGrabberDevice(String deviceId) => _unsupported();

  @override
  Future<List<MediaGrabberDeviceChannel>> fetchGrabberDeviceChannels(String deviceId) => _unsupported();

  @override
  Future<LiveTvActivityResult<MediaGrabberDevice?>> scanGrabberDevice(
    String deviceId, {
    String? source,
    Map<String, Object?> prefs = const {},
    String? network,
    String? country,
  }) => _unsupported();

  @override
  Future<MediaGrabberDevice?> cancelGrabberDeviceScan(String deviceId) => _unsupported();

  @override
  Future<MediaGrabberDevice?> saveGrabberDeviceChannelMap(String deviceId, MediaGrabberChannelMapRequest request) =>
      _unsupported();

  @override
  Future<void> updateGrabberDevicePrefs(String deviceId, Map<String, Object?> prefs) => _unsupported();

  @override
  String buildGrabberDeviceThumbUrl(String deviceId, int version) => _unsupportedSync();

  @override
  Future<List<LiveTvCountry>> fetchEpgCountries() => _unsupported();

  @override
  Future<List<LiveTvLanguage>> fetchEpgLanguages() => _unsupported();

  @override
  Future<List<LiveTvRegion>> fetchEpgRegions(String country, String epgId) => _unsupported();

  @override
  Future<LiveTvLineupResult> fetchEpgLineups(String country, String epgId, {String? postalCode, String? region}) =>
      _unsupported();

  @override
  Future<List<LiveTvChannel>> fetchEpgChannelsForLineup(String lineupUri) => _unsupported();

  @override
  Future<List<LiveTvLineup>> fetchEpgChannelsForLineups(List<String> lineupUris) => _unsupported();

  @override
  Future<List<ChannelMapping>> computeEpgChannelMap({required String deviceUri, required String lineupUri}) =>
      _unsupported();

  @override
  Future<LiveTvActivityResult<Map<String, dynamic>?>> findBestLineup({
    required String deviceUri,
    required String lineupGroupUri,
  }) => _unsupported();

  @override
  Future<List<SubscriptionTemplate>> getSubscriptionTemplate(String guid) => _client._getSubscriptionTemplate(guid);

  @override
  Future<List<MediaSubscription>> fetchRecordingRules({bool includeGrabs = true, bool includeStorage = true}) =>
      _client._fetchRecordingRules();

  @override
  Future<MediaSubscription?> fetchRecordingRule(
    String subscriptionId, {
    bool includeGrabs = true,
    bool includeStorage = true,
  }) async {
    final series = await _client._fetchTimerDto(subscriptionId, series: true);
    if (series != null) return EmbyLiveTvDvrMappers.seriesTimerToSubscription(series);
    final timer = await _client._fetchTimerDto(subscriptionId, series: false);
    if (timer != null) return EmbyLiveTvDvrMappers.timerToSubscription(timer);
    return null;
  }

  @override
  Future<MediaSubscription?> createRecordingRule(MediaSubscriptionCreateRequest request) =>
      _client._createRecordingRule(request);

  @override
  Future<MediaSubscription?> updateRecordingRule(String subscriptionId, Map<String, Object?> prefs) =>
      _client._updateRecordingRule(subscriptionId, prefs);

  @override
  Future<void> deleteRecordingRule(String subscriptionId) => _client._deleteRecordingRule(subscriptionId);

  @override
  Future<MediaSubscription?> moveRecordingRule(String subscriptionId, {String? afterSubscriptionId}) => _unsupported();

  @override
  Future<void> processRecordingRules() async {}

  @override
  Future<List<MediaGrabOperation>> fetchScheduledRecordings() => _client._fetchScheduledRecordings();

  @override
  Future<void> cancelGrab(String operationId) => _client._cancelGrab(operationId);

  @override
  Future<List<MediaSubscription>> fetchSubscriptionMapping({
    required String providerId,
    required List<String> ratingKeys,
    bool includeStorage = true,
  }) => _unsupported();

  @override
  Future<List<MediaProviderInfo>> fetchMediaProviders() => _unsupported();

  @override
  Future<void> registerMediaProvider(String url) => _unsupported();

  @override
  Future<void> refreshMediaProviders() => _unsupported();

  @override
  Future<void> unregisterMediaProvider(String providerId) => _unsupported();

  @override
  Future<List<LiveTvSession>> fetchLiveTvSessionsDetailed() => _unsupported();

  @override
  Future<LiveTvSession?> fetchLiveTvSession(String sessionId) => _unsupported();

  @override
  Uri buildNotificationWebSocketUri({List<String>? filters}) => _unsupportedSync();

  @override
  Uri buildNotificationEventSourceUri({List<String>? filters}) => _unsupportedSync();
}

/// A Emby live playback session: one negotiated direct-stream URL plus
/// `/Sessions/Playing*` heartbeats via [JellyfinLiveSessionTracker]. No
/// program-scoped session and no time-shift — [recover] re-opens the same
/// session-less URL.
class _EmbyLiveTvPlaybackSession implements LiveTvPlaybackSession {
  final EmbyClient _client;
  final String _channelKey;
  final String _url;
  final JellyfinLiveSessionTracker _tracker;

  _EmbyLiveTvPlaybackSession(this._client, this._channelKey, LiveTvStreamResolution resolution)
    : _url = resolution.url,
      _tracker = JellyfinLiveSessionTracker(playSessionId: resolution.playSessionId);

  @override
  LiveProgramInfo get program => LiveProgramInfo.none;

  @override
  CaptureBuffer? get captureBuffer => null;

  @override
  bool get canTimeShift => false;

  @override
  Future<String?> streamUrlAt({int? offsetSeconds}) async => offsetSeconds == null ? _url : null;

  @override
  Future<CaptureBuffer?> reportTimeline({
    required String state,
    required int positionMs,
    required int durationMs,
  }) async {
    await _tracker.report(
      client: _client,
      itemId: _channelKey,
      state: state,
      position: Duration(milliseconds: positionMs),
      duration: Duration(milliseconds: durationMs),
    );
    return null;
  }

  @override
  Future<LiveTvPlaybackSession?> recover({required bool directStream, required bool directStreamAudio}) async {
    final resolution = await _client.liveTv.resolveStreamUrl(
      _channelKey,
      directStream: directStream,
      directStreamAudio: directStreamAudio,
    );
    if (resolution == null) return null;
    return _EmbyLiveTvPlaybackSession(_client, _channelKey, resolution);
  }
}
