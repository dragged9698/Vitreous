import 'dart:ui' show Rect;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../models/always_on_top_mode.dart';
import 'linux_window_service.dart';
import 'settings_service.dart';

/// Desktop floating-window PiP using [window_manager] resize + keep-above.
class DesktopPipService {
  DesktopPipService._();

  static final ValueNotifier<bool> isActive = ValueNotifier(false);

  static Rect? _savedBounds;
  static bool _savedAlwaysOnTop = false;

  static bool get isSupported => Platform.isLinux || Platform.isWindows;

  static Future<bool> enter() async {
    if (!isSupported || isActive.value) return false;

    final settings = SettingsService.instance;
    final width = settings.read(SettingsService.desktopPipWidth).clamp(320, 3840);
    final height = settings.read(SettingsService.desktopPipHeight).clamp(180, 2160);
    final x = settings.read(SettingsService.desktopPipX);
    final y = settings.read(SettingsService.desktopPipY);

    _savedBounds = await windowManager.getBounds();
    _savedAlwaysOnTop = Platform.isLinux
        ? await LinuxWindowService.isKeepAbove()
        : await windowManager.isAlwaysOnTop();

    final screen = await windowManager.getSize();
    final left = x >= 0 ? x.toDouble() : (screen.width - width - 24);
    final top = y >= 0 ? y.toDouble() : (screen.height - height - 24);

    await windowManager.setBounds(Rect.fromLTWH(left, top, width.toDouble(), height.toDouble()));
    await _setAlwaysOnTop(true);
    isActive.value = true;
    return true;
  }

  static Future<void> exit() async {
    if (!isSupported || !isActive.value) return;

    final bounds = _savedBounds;
    if (bounds != null) {
      await windowManager.setBounds(bounds);
    }
    await _setAlwaysOnTop(_savedAlwaysOnTop);
    _savedBounds = null;
    isActive.value = false;
  }

  static Future<(bool, String?)> toggle() async {
    if (!isSupported) return (false, 'not_supported');
    if (isActive.value) {
      await exit();
      return (true, null);
    }
    final ok = await enter();
    return (ok, ok ? null : 'failed');
  }

  /// Persist current window bounds as the PiP preset (for next entry).
  static Future<void> saveCurrentBoundsAsPreset() async {
    if (!isSupported) return;
    final bounds = await windowManager.getBounds();
    final settings = SettingsService.instance;
    await settings.write(SettingsService.desktopPipWidth, bounds.width.round());
    await settings.write(SettingsService.desktopPipHeight, bounds.height.round());
    await settings.write(SettingsService.desktopPipX, bounds.left.round());
    await settings.write(SettingsService.desktopPipY, bounds.top.round());
  }

  static Future<void> _setAlwaysOnTop(bool enabled) async {
    if (Platform.isLinux) {
      await LinuxWindowService.setKeepAbove(enabled);
    } else {
      await windowManager.setAlwaysOnTop(enabled);
    }
  }

  /// Apply [AlwaysOnTopMode] for desktop playback chrome.
  static Future<void> applyMode(AlwaysOnTopMode mode, {required bool isPlaying}) async {
    if (!Platform.isLinux && !Platform.isWindows && !Platform.isMacOS) return;

    final enabled = switch (mode) {
      AlwaysOnTopMode.on => true,
      AlwaysOnTopMode.whenPlaying => isPlaying,
      AlwaysOnTopMode.off => false,
    };

    if (Platform.isLinux) {
      await LinuxWindowService.setKeepAbove(enabled);
    } else {
      await windowManager.setAlwaysOnTop(enabled);
    }
  }
}
