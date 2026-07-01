import 'package:uuid/uuid.dart';

/// Stable device/client identity for Emby API headers.
class EmbyRequestContext {
  EmbyRequestContext({
    this.clientName = 'EmbyPlayer',
    this.clientVersion = '1.0.0',
    String? deviceName,
    String? deviceId,
  })  : deviceName = deviceName ?? 'Linux Desktop',
        deviceId = deviceId ?? const Uuid().v4();

  final String clientName;
  final String clientVersion;
  final String deviceName;
  final String deviceId;

  EmbyRequestContext copyWith({
    String? clientName,
    String? clientVersion,
    String? deviceName,
    String? deviceId,
  }) {
    return EmbyRequestContext(
      clientName: clientName ?? this.clientName,
      clientVersion: clientVersion ?? this.clientVersion,
      deviceName: deviceName ?? this.deviceName,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
