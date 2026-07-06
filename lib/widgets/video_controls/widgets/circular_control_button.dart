import 'package:flutter/material.dart';

import '../emby_player_glass.dart';

/// Glass circular transport button for mobile player controls.
class CircularControlButton extends StatelessWidget {
  final String semanticLabel;
  final IconData icon;
  final double iconSize;
  final VoidCallback? onPressed;

  const CircularControlButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.iconSize,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = (iconSize + 20).clamp(48.0, 72.0);
    return EmbyPlayerGlassIconButton(
      semanticLabel: semanticLabel,
      icon: icon,
      iconSize: iconSize,
      size: size,
      onPressed: onPressed,
    );
  }
}
