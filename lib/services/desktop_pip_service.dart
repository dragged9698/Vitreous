import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../models/always_on_top_mode.dart';
import '../utils/app_logger.dart';
import 'linux_window_service.dart';
import 'settings_service.dart';

/// Desktop floating-window PiP. Linux uses native GTK PiP (KDE/Wayland SSD);
/// Windows uses [window_manager].
class DesktopPipService {
  DesktopPipService._();

  static final ValueNotifier<bool> isActive = ValueNotifier(false);

  static const double pipCornerRadius = 12;

  static Rect? _savedBounds;
  static bool _savedAlwaysOnTop = false;

  static bool get isSupported => Platform.isLinux || Platform.isWindows;

  static double? _lockedAspectRatio;

  /// Snap [width]/[height] to [aspectRatio] (width/height), keeping width.
  static (double width, double height) _fitToAspect(double width, double height, double aspectRatio) {
    if (aspectRatio <= 0 || !aspectRatio.isFinite) return (width, height);
    final targetHeight = width / aspectRatio;
    if (targetHeight < 135) {
      return (135 * aspectRatio, 135);
    }
    return (width, targetHeight);
  }

  static Future<bool> enter({
    int? videoWidth,
    int? videoHeight,
    bool lockAspectRatio = false,
  }) async {
    if (!isSupported || isActive.value) return false;

    final settings = SettingsService.instance;
    var width = settings.read(SettingsService.desktopPipWidth).clamp(320, 3840).toDouble();
    var height = settings.read(SettingsService.desktopPipHeight).clamp(180, 2160).toDouble();
    final x = settings.read(SettingsService.desktopPipX);
    final y = settings.read(SettingsService.desktopPipY);

    double? aspectRatio;
    if (lockAspectRatio && videoWidth != null && videoHeight != null && videoWidth > 0 && videoHeight > 0) {
      aspectRatio = videoWidth / videoHeight;
      final fitted = _fitToAspect(width, height, aspectRatio);
      width = fitted.$1;
      height = fitted.$2;
    }
    _lockedAspectRatio = aspectRatio;

    if (Platform.isLinux) {
      _savedBounds = await LinuxWindowService.getWindowBounds() ?? await windowManager.getBounds();
    } else {
      _savedBounds = await windowManager.getBounds();
    }

    _savedAlwaysOnTop = Platform.isLinux
        ? await LinuxWindowService.isKeepAbove()
        : await windowManager.isAlwaysOnTop();

    appLogger.i(
      '[DesktopPip] enter savedBounds: $_savedBounds alwaysOnTopBefore=$_savedAlwaysOnTop '
      'lockAspect=$lockAspectRatio aspect=$aspectRatio size=${width.round()}x${height.round()}',
    );

    final screen = await windowManager.getSize();
    final left = x >= 0 ? x.toDouble() : (screen.width - width - 24);
    final top = y >= 0 ? y.toDouble() : (screen.height - height - 24);

    final ok = Platform.isLinux
        ? await LinuxWindowService.enterDesktopPip(
            x: left.round(),
            y: top.round(),
            width: width.round(),
            height: height.round(),
          )
        : await _enterWindowsPip(left, top, width, height);

    if (!ok) {
      _lockedAspectRatio = null;
      return false;
    }

    await _applyAspectRatioLock(aspectRatio);
    await _setAlwaysOnTop(true);
    isActive.value = true;
    return true;
  }

  static Future<void> _applyAspectRatioLock(double? aspectRatio) async {
    if (aspectRatio == null || aspectRatio <= 0) {
      await windowManager.setAspectRatio(0);
      return;
    }
    await windowManager.setAspectRatio(aspectRatio);
    appLogger.i('[DesktopPip] aspect ratio locked to $aspectRatio');
  }

  static Future<bool> _enterWindowsPip(double left, double top, double width, double height) async {
    await windowManager.setMinimumSize(const Size(240, 135));
    await windowManager.setAsFrameless();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setBackgroundColor(const Color(0x00000000));
    await windowManager.setBounds(Rect.fromLTWH(left, top, width, height));
    return true;
  }

  static Future<void> exit() async {
    if (!isSupported || !isActive.value) return;

    final bounds = _savedBounds;
    appLogger.i('[DesktopPip] exit restoring bounds=$bounds alwaysOnTop=$_savedAlwaysOnTop');

    // Persist the PiP size/position the user settled on before restoring the main window.
    await saveCurrentBoundsAsPreset();

    if (Platform.isLinux) {
      if (bounds != null) {
        await LinuxWindowService.exitDesktopPip(
          x: bounds.left.round(),
          y: bounds.top.round(),
          width: bounds.width.round(),
          height: bounds.height.round(),
        );
      } else {
        await LinuxWindowService.exitDesktopPip();
      }
    } else {
      if (bounds != null) {
        await windowManager.setBounds(bounds);
      }
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setBackgroundColor(const Color(0xFF000000));
    }

    await _setAlwaysOnTop(_savedAlwaysOnTop);
    await _applyAspectRatioLock(null);
    _lockedAspectRatio = null;
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

  /// Whether PiP resize is locked to the current video aspect ratio.
  static bool get isAspectRatioLocked => _lockedAspectRatio != null;

  /// Persist current window bounds as the PiP preset (for next entry).
  static Future<void> saveCurrentBoundsAsPreset() async {
    if (!isSupported) return;
    final bounds = Platform.isLinux
        ? await LinuxWindowService.getWindowBounds() ?? await windowManager.getBounds()
        : await windowManager.getBounds();
    final settings = SettingsService.instance;
    await settings.write(SettingsService.desktopPipWidth, bounds.width.round());
    await settings.write(SettingsService.desktopPipHeight, bounds.height.round());
    await settings.write(SettingsService.desktopPipX, bounds.left.round());
    await settings.write(SettingsService.desktopPipY, bounds.top.round());
  }

  static Future<void> startDragging() async {
    if (Platform.isLinux) {
      await LinuxWindowService.startWindowDrag();
    } else {
      await windowManager.startDragging();
    }
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

    appLogger.i('[DesktopPip] applyMode mode=$mode isPlaying=$isPlaying enabled=$enabled');

    if (Platform.isLinux) {
      await LinuxWindowService.setKeepAbove(enabled);
    } else {
      await windowManager.setAlwaysOnTop(enabled);
    }
  }
}
