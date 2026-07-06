import '../media/media_backend.dart';

import '../services/plex_auth_service.dart' show PlexServer;

/// Identifier of a backend kind a [Connection] points at.
enum ConnectionKind {
  emby,
  jellyfin;

  String get id => name;

  static ConnectionKind fromId(String id) => switch (id) {
    'emby' => ConnectionKind.emby,
    'jellyfin' => ConnectionKind.jellyfin,
    _ => throw ArgumentError('Unknown ConnectionKind id: $id'),
  };

  MediaBackend get backend => switch (this) {
    ConnectionKind.emby => MediaBackend.emby,
    ConnectionKind.jellyfin => MediaBackend.jellyfin,
  };
}

/// Health snapshot for a connection.
enum ConnectionStatus { unknown, online, offline, authError, disabled }

/// A media server connection — a unit of authentication the user added.
sealed class Connection {
  String get id;
  ConnectionKind get kind;
  String get displayName;
  ConnectionStatus get status;
  DateTime get createdAt;
  DateTime? get lastAuthenticatedAt;

  MediaBackend get backend => kind.backend;

  String get displayLabel;
  String? get displaySubtitle;

  Map<String, Object?> toConfigJson();
}

/// A single-server Emby connection.
class EmbyConnection extends Connection {
  @override
  final String id;

  @override
  final ConnectionStatus status;

  @override
  final DateTime createdAt;

  @override
  final DateTime? lastAuthenticatedAt;

  final String baseUrl;
  final List<String> baseUrls;
  final String serverName;
  final String serverMachineId;
  final String userId;
  final String userName;
  final String accessToken;
  final String deviceId;
  final bool isAdministrator;

  EmbyConnection({
    required this.id,
    required this.baseUrl,
    List<String>? baseUrls,
    required this.serverName,
    required this.serverMachineId,
    required this.userId,
    required this.userName,
    required this.accessToken,
    required this.deviceId,
    this.isAdministrator = false,
    this.status = ConnectionStatus.unknown,
    required this.createdAt,
    this.lastAuthenticatedAt,
  }) : baseUrls = _normalizeBaseUrls(baseUrl, baseUrls);

  @override
  ConnectionKind get kind => ConnectionKind.emby;

  @override
  String get displayName => '$userName · $serverName';

  @override
  String get displayLabel => serverName;

  @override
  String? get displaySubtitle {
    final extraCount = baseUrls.length - 1;
    final suffix = extraCount > 0 ? ' +$extraCount' : '';
    return '$userName · ${_truncateUrl(baseUrl)}$suffix';
  }

  /// Emby REST path for the authenticated user (`/Users/{userId}`).
  /// Some Emby builds 500 on `/Users/Me`.
  String get embyCurrentUserPath => userId.isNotEmpty ? '/Users/$userId' : '/Users/Me';

  /// Emby continue-watching endpoint (`/Users/{userId}/Items/Resume`).
  String get embyResumeItemsPath => userId.isNotEmpty ? '/Users/$userId/Items/Resume' : '/UserItems/Resume';

  static String _truncateUrl(String url) {
    if (url.length <= 40) return url;
    return '${url.substring(0, 37)}…';
  }

  static List<String> _normalizeBaseUrls(String activeBaseUrl, List<String>? urls) {
    final result = <String>[];
    final seen = <String>{};

    void add(String url) {
      final trimmed = url.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) return;
      result.add(trimmed);
    }

    add(activeBaseUrl);
    for (final url in urls ?? const <String>[]) {
      add(url);
    }
    return List.unmodifiable(result);
  }

  EmbyConnection copyWith({
    String? id,
    String? baseUrl,
    List<String>? baseUrls,
    String? serverName,
    String? serverMachineId,
    String? userId,
    String? userName,
    String? accessToken,
    String? deviceId,
    bool? isAdministrator,
    ConnectionStatus? status,
    DateTime? createdAt,
    DateTime? lastAuthenticatedAt,
  }) {
    final nextBaseUrl = baseUrl ?? this.baseUrl;
    return EmbyConnection(
      id: id ?? this.id,
      baseUrl: nextBaseUrl,
      baseUrls: baseUrls ?? this.baseUrls,
      serverName: serverName ?? this.serverName,
      serverMachineId: serverMachineId ?? this.serverMachineId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      accessToken: accessToken ?? this.accessToken,
      deviceId: deviceId ?? this.deviceId,
      isAdministrator: isAdministrator ?? this.isAdministrator,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
    );
  }

  @override
  Map<String, Object?> toConfigJson() {
    return {
      'baseUrl': baseUrl,
      'baseUrls': baseUrls,
      'serverName': serverName,
      'serverMachineId': serverMachineId,
      'userId': userId,
      'userName': userName,
      'accessToken': accessToken,
      'deviceId': deviceId,
      'isAdministrator': isAdministrator,
    };
  }

  factory EmbyConnection.fromConfigJson({
    required String id,
    required Map<String, Object?> json,
    required ConnectionStatus status,
    required DateTime createdAt,
    DateTime? lastAuthenticatedAt,
  }) {
    final rawBaseUrls = json['baseUrls'];
    final baseUrls = rawBaseUrls is List ? rawBaseUrls.whereType<String>().toList(growable: false) : const <String>[];
    final rawBaseUrl = json['baseUrl'] as String?;
    final baseUrl = rawBaseUrl != null && rawBaseUrl.isNotEmpty
        ? rawBaseUrl
        : (baseUrls.isNotEmpty ? baseUrls.first : '');
    return EmbyConnection(
      id: id,
      baseUrl: baseUrl,
      baseUrls: baseUrls,
      serverName: json['serverName'] as String? ?? 'Emby',
      serverMachineId: json['serverMachineId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      isAdministrator: json['isAdministrator'] as bool? ?? false,
      status: status,
      createdAt: createdAt,
      lastAuthenticatedAt: lastAuthenticatedAt,
    );
  }
}

/// A single-server Jellyfin connection (Vitreous-native API paths).
class JellyfinConnection extends Connection {
  @override
  final String id;

  @override
  final ConnectionStatus status;

  @override
  final DateTime createdAt;

  @override
  final DateTime? lastAuthenticatedAt;

  final String baseUrl;
  final List<String> baseUrls;
  final String serverName;
  final String serverMachineId;
  final String userId;
  final String userName;
  final String accessToken;
  final String deviceId;
  final bool isAdministrator;

  JellyfinConnection({
    required this.id,
    required this.baseUrl,
    List<String>? baseUrls,
    required this.serverName,
    required this.serverMachineId,
    required this.userId,
    required this.userName,
    required this.accessToken,
    required this.deviceId,
    this.isAdministrator = false,
    this.status = ConnectionStatus.unknown,
    required this.createdAt,
    this.lastAuthenticatedAt,
  }) : baseUrls = EmbyConnection._normalizeBaseUrls(baseUrl, baseUrls);

  @override
  ConnectionKind get kind => ConnectionKind.jellyfin;

  @override
  String get displayName => '$userName · $serverName';

  @override
  String get displayLabel => serverName;

  @override
  String? get displaySubtitle {
    final extraCount = baseUrls.length - 1;
    final suffix = extraCount > 0 ? ' +$extraCount' : '';
    return '$userName · ${EmbyConnection._truncateUrl(baseUrl)}$suffix';
  }

  JellyfinConnection copyWith({
    String? id,
    String? baseUrl,
    List<String>? baseUrls,
    String? serverName,
    String? serverMachineId,
    String? userId,
    String? userName,
    String? accessToken,
    String? deviceId,
    bool? isAdministrator,
    ConnectionStatus? status,
    DateTime? createdAt,
    DateTime? lastAuthenticatedAt,
  }) {
    final nextBaseUrl = baseUrl ?? this.baseUrl;
    return JellyfinConnection(
      id: id ?? this.id,
      baseUrl: nextBaseUrl,
      baseUrls: baseUrls ?? this.baseUrls,
      serverName: serverName ?? this.serverName,
      serverMachineId: serverMachineId ?? this.serverMachineId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      accessToken: accessToken ?? this.accessToken,
      deviceId: deviceId ?? this.deviceId,
      isAdministrator: isAdministrator ?? this.isAdministrator,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      lastAuthenticatedAt: lastAuthenticatedAt ?? this.lastAuthenticatedAt,
    );
  }

  @override
  Map<String, Object?> toConfigJson() {
    return {
      'baseUrl': baseUrl,
      'baseUrls': baseUrls,
      'serverName': serverName,
      'serverMachineId': serverMachineId,
      'userId': userId,
      'userName': userName,
      'accessToken': accessToken,
      'deviceId': deviceId,
      'isAdministrator': isAdministrator,
    };
  }

  factory JellyfinConnection.fromConfigJson({
    required String id,
    required Map<String, Object?> json,
    required ConnectionStatus status,
    required DateTime createdAt,
    DateTime? lastAuthenticatedAt,
  }) {
    final rawBaseUrls = json['baseUrls'];
    final baseUrls = rawBaseUrls is List ? rawBaseUrls.whereType<String>().toList(growable: false) : const <String>[];
    final rawBaseUrl = json['baseUrl'] as String?;
    final baseUrl = rawBaseUrl != null && rawBaseUrl.isNotEmpty
        ? rawBaseUrl
        : (baseUrls.isNotEmpty ? baseUrls.first : '');
    return JellyfinConnection(
      id: id,
      baseUrl: baseUrl,
      baseUrls: baseUrls,
      serverName: json['serverName'] as String? ?? 'Jellyfin',
      serverMachineId: json['serverMachineId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      isAdministrator: json['isAdministrator'] as bool? ?? false,
      status: status,
      createdAt: createdAt,
      lastAuthenticatedAt: lastAuthenticatedAt,
    );
  }
}

/// Deprecated Plex account stub — Plex backend removed in Emby fork.
@Deprecated('Plex removed')
class PlexAccountConnection extends Connection {
  PlexAccountConnection({
    required this.id,
    this.accountToken = '',
    this.clientIdentifier = '',
    this.accountLabel = 'Plex',
    this.servers = const [],
    this.status = ConnectionStatus.unknown,
    required this.createdAt,
    this.lastAuthenticatedAt,
  });

  @override
  final String id;
  @override
  final ConnectionStatus status;
  @override
  final DateTime createdAt;
  @override
  final DateTime? lastAuthenticatedAt;

  final String accountToken;
  final String clientIdentifier;
  final String accountLabel;
  final List<PlexServer> servers;

  @override
  ConnectionKind get kind => ConnectionKind.emby;

  @override
  String get displayName => accountLabel;

  @override
  String get displayLabel => accountLabel;

  @override
  String? get displaySubtitle => null;

  PlexAccountConnection copyWith({List<PlexServer>? servers}) => this;

  @override
  Map<String, Object?> toConfigJson() => {};

  factory PlexAccountConnection.fromConfigJson({
    required String id,
    required Map<String, Object?> json,
    required ConnectionStatus status,
    required DateTime createdAt,
    DateTime? lastAuthenticatedAt,
  }) =>
      PlexAccountConnection(id: id, createdAt: createdAt, lastAuthenticatedAt: lastAuthenticatedAt);
}
