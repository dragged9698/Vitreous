import 'package:flutter/material.dart';

import 'emby_glass_shell.dart';

/// Scroll scaffold with keyboard navigation — delegates to [EmbyGlassScrollScaffold].
///
/// Kept for call-site compatibility while all settings/profile screens use liquid
/// glass chrome from `liquid_glass_widgets`.
class FocusedScrollScaffold extends StatelessWidget {
  const FocusedScrollScaffold({
    super.key,
    required this.title,
    required this.slivers,
    this.actions,
    this.pinned = true,
    this.automaticallyImplyLeading = true,
    this.onBackPressed,
  });

  final Widget title;
  final List<Widget> slivers;
  final List<Widget>? actions;
  final bool pinned;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return EmbyGlassScrollScaffold(
      title: title,
      slivers: slivers,
      actions: actions,
      pinned: pinned,
      automaticallyImplyLeading: automaticallyImplyLeading,
      onBackPressed: onBackPressed,
    );
  }
}
