import 'dart:io';

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../utils/app_logger.dart';

/// Linux window helpers that target the real GTK toplevel (and MPV embed popup).
///
/// Routes through the MPV plugin so keep-above and desktop PiP hit the same
/// GtkApplicationWindow KDE/Wayland sees — including HDR embed surfaces.
class LinuxWindowService {
  static const _channel = MethodChannel('com.vitreous/mpv_player');

  static bool get isSupported => Platform.isLinux;

  static Future<void> setKeepAbove(bool value) async {
    if (!isSupported) return;
    appLogger.i('[LinuxWindow] setKeepAbove request value=$value');
    try {
      await _channel.invokeMethod<void>('setKeepAbove', {'value': value});
      appLogger.i('[LinuxWindow] setKeepAbove native channel ok value=$value');
    } on MissingPluginException {
      appLogger.w('[LinuxWindow] setKeepAbove missing MPV channel, window_manager fallback');
      await windowManager.setAlwaysOnTop(value);
      return;
    }
    await windowManager.setAlwaysOnTop(value);
    final wmState = await windowManager.isAlwaysOnTop();
    appLogger.i('[LinuxWindow] setKeepAbove done value=$value window_manager=$wmState');
  }

  static Future<bool> isKeepAbove() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isKeepAbove');
      appLogger.d('[LinuxWindow] isKeepAbove native=$result');
      return result ?? false;
    } on MissingPluginException {
      final wm = await windowManager.isAlwaysOnTop();
      appLogger.d('[LinuxWindow] isKeepAbove window_manager=$wm');
      return wm;
    }
  }

  static Future<Rect?> getWindowBounds() async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('getWindowBounds');
      if (result == null) return null;
      final bounds = Rect.fromLTWH(
        (result['x'] as num?)?.toDouble() ?? 0,
        (result['y'] as num?)?.toDouble() ?? 0,
        (result['width'] as num?)?.toDouble() ?? 0,
        (result['height'] as num?)?.toDouble() ?? 0,
      );
      appLogger.d('[LinuxWindow] getWindowBounds $bounds');
      return bounds;
    } on MissingPluginException {
      final bounds = await windowManager.getBounds();
      appLogger.d('[LinuxWindow] getWindowBounds window_manager=$bounds');
      return bounds;
    }
  }

  static Future<bool> enterDesktopPip({
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    if (!isSupported) return false;
    appLogger.i('[LinuxWindow] enterDesktopPip x=$x y=$y w=$width h=$height');
    try {
      final result = await _channel.invokeMethod<bool>('enterDesktopPip', {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      });
      appLogger.i('[LinuxWindow] enterDesktopPip native result=$result');
      return result ?? false;
    } on MissingPluginException {
      appLogger.w('[LinuxWindow] enterDesktopPip missing MPV channel');
      return false;
    }
  }

  static Future<bool> exitDesktopPip({int? x, int? y, int? width, int? height}) async {
    if (!isSupported) return false;
    appLogger.i('[LinuxWindow] exitDesktopPip x=$x y=$y w=$width h=$height');
    try {
      final args = (x != null && y != null && width != null && height != null)
          ? {'x': x, 'y': y, 'width': width, 'height': height}
          : null;
      final result = await _channel.invokeMethod<bool>('exitDesktopPip', args);
      appLogger.i('[LinuxWindow] exitDesktopPip native result=$result');
      return result ?? false;
    } on MissingPluginException {
      appLogger.w('[LinuxWindow] exitDesktopPip missing MPV channel');
      return false;
    }
  }

  static Future<bool> isDesktopPipActive() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isDesktopPipActive');
      return result ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> startWindowDrag() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('startWindowDrag');
    } on MissingPluginException {
      await windowManager.startDragging();
    }
  }
}
