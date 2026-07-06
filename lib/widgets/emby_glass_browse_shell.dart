import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../theme/emby_glass_theme.dart';
import '../utils/platform_detector.dart';

/// Browse/detail body on [GlassScaffold] — shell backdrop + content-aware chrome.
///
/// Use with opaque content (grids, lists). Pair with [GlassAppBar] / custom
/// floating toolbars; do not wrap [MediaCard] grids in glass.
class EmbyGlassBrowseShell extends StatelessWidget {
  const EmbyGlassBrowseShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformDetector.shouldUseSideNavigation(context)) {
      return child;
    }
    return GlassScaffold(
      background: embyAppBackdrop(context),
      contentAwareBrightness: true,
      statusBarStyle: GlassStatusBarStyle.auto,
      body: child,
    );
  }
}

/// Full [GlassScaffold] for screens with standard app bar + scroll body.
class EmbyGlassBrowseScaffold extends StatelessWidget {
  const EmbyGlassBrowseScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
  });

  final Widget body;
  final GlassAppBar? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (!PlatformDetector.shouldUseSideNavigation(context)) {
      return Scaffold(body: body, floatingActionButton: floatingActionButton);
    }
    return GlassScaffold(
      background: embyAppBackdrop(context),
      contentAwareBrightness: true,
      statusBarStyle: GlassStatusBarStyle.auto,
      appBar: appBar,
      bottomBar: bottomBar,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
