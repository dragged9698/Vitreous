import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_logger.dart';
import 'settings_service.dart';

/// Resolves the device name sent in Emby/Jellyfin `Authorization` headers.
class DeviceNameService {
  DeviceNameService._();

  static String? _cached;

  /// User override from settings, else OS hostname/computer name, else app name.
  static Future<String> resolve() async {
    final custom = SettingsService.instanceOrNull?.read(SettingsService.customDeviceName)?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return _resolveSystemName();
  }

  static Future<String> _resolveSystemName() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        _cached = '${android.brand} ${android.model}'.trim();
      } else if (Platform.isIOS) {
        _cached = (await deviceInfo.iosInfo).name;
      } else if (Platform.isMacOS) {
        _cached = (await deviceInfo.macOsInfo).computerName;
      } else if (Platform.isWindows) {
        _cached = (await deviceInfo.windowsInfo).computerName;
      } else if (Platform.isLinux) {
        final host = Platform.localHostname.trim();
        _cached = (host.isNotEmpty && host != 'localhost') ? host : (await deviceInfo.linuxInfo).name;
      } else {
        _cached = Platform.operatingSystem;
      }
    } catch (e, st) {
      appLogger.w('DeviceNameService: failed to resolve hostname', error: e, stackTrace: st);
      _cached = 'Emby Player';
    }

    final name = _cached?.trim();
    if (name == null || name.isEmpty) return 'Emby Player';
    return name;
  }

  @visibleForTesting
  static void resetCacheForTesting() => _cached = null;
}
