import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../media/media_item.dart';
import '../media/media_kind.dart';
import '../theme/mono_tokens.dart';
import 'app_icon.dart';

/// Top-left movie/TV badge for mixed-library browse grids.
class MediaKindBadge extends StatelessWidget {
  final MediaItem item;

  const MediaKindBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      MediaKind.movie => Symbols.movie_rounded,
      MediaKind.show => Symbols.tv_rounded,
      _ => null,
    };
    if (icon == null) return const SizedBox.shrink();

    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: AppIcon(icon, fill: 1, size: 14, color: tokens(context).text),
      ),
    );
  }
}
