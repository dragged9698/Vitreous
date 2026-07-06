import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:emby_player/utils/formatters.dart';
import 'package:emby_player/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../media/media_item.dart';
import '../../../watch_together/widgets/watch_together_overlay.dart';
import '../../../watch_together/providers/watch_together_provider.dart';

/// Header layout style for video controls
enum VideoHeaderStyle {
  /// Multi-line: Series name on first line, episode info on second line
  multiLine,

  /// Single-line: All info combined with separators (for macOS)
  singleLine,
}

/// Shared header widget for video controls with back button and title.
///
/// Displays the video title with optional series/episode information.
/// Supports both single-line (macOS) and multi-line (other platforms) layouts.
class VideoControlsHeader extends StatelessWidget {
  final MediaItem metadata;
  final VideoHeaderStyle style;

  /// When true, the header sizes to its content instead of expanding full width.
  final bool compactWidth;

  /// Max width for title text when [compactWidth] is true.
  final double? maxTitleWidth;

  /// Optional trailing widget (e.g., track/chapter controls)
  final Widget? trailing;

  /// Optional callback for back button. If null, defaults to Navigator.pop(true).
  final VoidCallback? onBack;

  const VideoControlsHeader({
    super.key,
    required this.metadata,
    this.style = VideoHeaderStyle.multiLine,
    this.compactWidth = false,
    this.maxTitleWidth,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final title = style == VideoHeaderStyle.singleLine ? _buildSingleLineTitle() : _buildMultiLineTitle();
    final titleWidget = compactWidth
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxTitleWidth ?? 560),
            child: title,
          )
        : Expanded(child: title);

    return Row(
      mainAxisSize: compactWidth ? MainAxisSize.min : MainAxisSize.max,
      children: [
        IconButton(
          icon: const AppIcon(Symbols.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          onPressed: onBack ?? () => Navigator.of(context).pop(true),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        const SizedBox(width: 8),
        titleWidget,
        Selector<WatchTogetherProvider, bool>(
          selector: (_, p) => p.isInSession,
          builder: (context, inSession, child) {
            if (!inSession) return const SizedBox.shrink();
            return const Padding(padding: .only(right: 8), child: WatchTogetherSessionIndicator());
          },
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildSingleLineTitle() {
    final seriesName = metadata.grandparentTitle ?? metadata.title!;
    final hasEpisodeInfo = metadata.parentIndex != null && metadata.index != null;

    final List<String> parts = [seriesName];

    if (hasEpisodeInfo) {
      parts.add('S${metadata.parentIndex}E${metadata.index}');
      parts.add(metadata.title!);
    }

    return Text(
      toBulletedString(parts),
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: .w500),
      maxLines: 1,
      overflow: .ellipsis,
    );
  }

  Widget _buildMultiLineTitle() {
    final List<String> secondLineParts = [];

    if (metadata.parentIndex != null && metadata.index != null) {
      secondLineParts.add('S${metadata.parentIndex}');
      secondLineParts.add('E${metadata.index}');
      secondLineParts.add(metadata.title!);
    }

    if (metadata.durationMs != null) {
      secondLineParts.add(formatDurationTextual(metadata.durationMs!));
    }

    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          metadata.grandparentTitle ?? metadata.title!,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: .bold),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        if (secondLineParts.isNotEmpty)
          Text(
            toBulletedString(secondLineParts),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 1,
            overflow: .ellipsis,
          ),
      ],
    );
  }
}
