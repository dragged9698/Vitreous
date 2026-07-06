import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/fullscreen_state_manager.dart';
import '../utils/platform_detector.dart';
import 'emby_shell_backdrop.dart';

const _glassQualityPrefKey = 'glass_quality';

Widget embyAppBackdrop(BuildContext context) => const EmbyShellBackdrop();

/// Solid page fill for push-layout tabs — no animated mesh behind the top chrome.
Color embyFlatPageColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0xFF0B0D14) : const Color(0xFFF3F4FA);
}

Widget embyFlatPageBackground(BuildContext context) => ColoredBox(color: embyFlatPageColor(context));

/// Resting pill for segmented controls on the shell backdrop.
Color embySegmentIndicatorColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? const Color(0x55FFFFFF) : const Color(0x44000000);
}

/// Segmented controls on the top chrome row sample the shell backdrop directly.
Widget embyGlassSegmentScope(BuildContext context, {required Widget child}) {
  return InheritedLiquidGlass(
    settings: embyChromeGlassSettings(context),
    quality: embyChromeGlassQuality(),
    avoidsRefraction: false,
    child: child,
  );
}

GlassThemeData embyDefaultGlassTheme() {
  return GlassThemeData.simple(blur: 18, thickness: 32, quality: GlassQuality.standard);
}

GlassThemeData embyGlassThemeData(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return GlassThemeData.simple(
    blur: isDark ? 20 : 14,
    thickness: 32,
    quality: GlassQuality.standard,
    brightness: Theme.of(context).brightness,
  );
}

LiquidGlassSettings embyChromeGlassSettings(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return LiquidGlassSettings(
    blur: isDark ? 22 : 16,
    thickness: 34,
    glassColor: isDark ? const Color(0x38FFFFFF) : const Color(0x55FFFFFF),
    refractiveIndex: 1.22,
    lightIntensity: isDark ? 0.85 : 1.1,
    ambientStrength: isDark ? 0.35 : 0.55,
  );
}

/// Linux Impeller: lightweight shader shows blocky UV artifacts — use BackdropFilter tier.
GlassQuality embyChromeGlassQuality() {
  if (PlatformDetector.isDesktopOS() && ui.ImageFilter.isShaderFilterSupported) {
    return GlassQuality.minimal;
  }
  return GlassQuality.standard;
}

const embyChromeCornerRadius = 22.0;
const embyChromeCornerRadiusCollapsed = 20.0;

EdgeInsets embyTopChromeInsets(BuildContext context) {
  var top = MediaQuery.paddingOf(context).top + 10;
  if (Platform.isMacOS && !FullscreenStateManager().isFullscreen) {
    top = top < 52 ? 52 : top;
  }
  return EdgeInsets.fromLTRB(16, top, 16, 10);
}

EdgeInsets embyFloatingChromeInsets(BuildContext context, {bool collapsed = false}) {
  var top = MediaQuery.paddingOf(context).top + (collapsed ? 10 : 14);
  if (Platform.isMacOS && !FullscreenStateManager().isFullscreen) {
    top = top < 52 ? 52 : top;
  }
  if (collapsed) {
    return EdgeInsets.fromLTRB(8, top, 6, 18);
  }
  return EdgeInsets.fromLTRB(14, top, 8, 18);
}

bool embyUseShellBackdrop(BuildContext context) => PlatformDetector.shouldUseSideNavigation(context);

// ignore: experimental_member_use
Future<GlassAdaptiveScopeConfig> loadEmbyGlassAdaptiveConfig() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_glassQualityPrefKey);
  final defaultQuality = PlatformDetector.isDesktopOS() && ui.ImageFilter.isShaderFilterSupported
      ? GlassQuality.minimal
      : GlassQuality.standard;
  final initial = saved != null ? GlassQuality.values.byName(saved) : null;
  // ignore: experimental_member_use
  return GlassAdaptiveScopeConfig(
    initialQuality: initial ?? defaultQuality,
    allowStepUp: true,
    onQualityChanged: (_, to) => prefs.setString(_glassQualityPrefKey, to.name),
  );
}

Widget embyGlassWrapApp({
  required Widget child,
  // ignore: experimental_member_use
  GlassAdaptiveScopeConfig? adaptiveConfig,
}) {
  return LiquidGlassWidgets.wrap(
    adaptiveQuality: true,
    adaptiveConfig: adaptiveConfig,
    theme: embyDefaultGlassTheme(),
    child: child,
  );
}
