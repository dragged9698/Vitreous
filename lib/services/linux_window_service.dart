import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Linux window helpers that target the real GTK toplevel (and MPV embed popup).
///
/// [window_manager] also calls `gtk_window_set_keep_above`, but routing through
/// the MPV plugin guarantees the same window KDE's "Keep above others" toggle
/// affects — including the HDR embed surface when active.
class LinuxWindowService {
  static const _channel = MethodChannel('com.plezy/mpv_player');

  static bool get isSupported => Platform.isLinux;

  static Future<void> setKeepAbove(bool value) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setKeepAbove', {'value': value});
    } on MissingPluginException {
      await windowManager.setAlwaysOnTop(value);
    }
  }

  static Future<bool> isKeepAbove() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isKeepAbove');
      return result ?? false;
    } on MissingPluginException {
      return windowManager.isAlwaysOnTop();
    }
  }
}
