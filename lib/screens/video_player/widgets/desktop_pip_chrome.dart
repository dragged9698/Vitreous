import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:window_manager/window_manager.dart';

import '../../../i18n/strings.g.dart';
import '../../../mpv/mpv.dart';
import '../../../services/desktop_pip_service.dart';
import '../../../services/settings_service.dart';
import '../../../utils/player_utils.dart';
import '../../../widgets/video_controls/emby_player_glass.dart';
import '../../../widgets/video_controls/icons.dart';
import '../../../widgets/video_controls/widgets/play_pause_stream_builder.dart';
import '../../../widgets/video_controls/widgets/video_timeline_bar.dart';

/// Always-on-top glass chrome for Linux/Windows desktop PiP.
///
/// Full player controls are hidden during PiP; this overlay supplies transport,
/// scrubbing, volume, and exit affordances over the video surface.
class VideoPlayerDesktopPipChrome extends StatefulWidget {
  const VideoPlayerDesktopPipChrome({
    super.key,
    required this.player,
    required this.onExitPip,
    required this.onPlayPause,
    required this.onSeek,
    required this.canControl,
    this.isLive = false,
  });

  final Player player;
  final VoidCallback onExitPip;
  final VoidCallback onPlayPause;
  final Future<void> Function(Duration position) onSeek;
  final bool canControl;
  final bool isLive;

  @override
  State<VideoPlayerDesktopPipChrome> createState() => _VideoPlayerDesktopPipChromeState();
}

class _VideoPlayerDesktopPipChromeState extends State<VideoPlayerDesktopPipChrome> {
  bool _hovering = false;
  bool _scrubbing = false;
  Duration? _scrubPreviewPosition;

  int get _seekTimeSmall => SettingsService.instance.read(SettingsService.seekTimeSmall);

  bool get _controlsVisible => _hovering || _scrubbing;

  Future<void> _seekByOffset(int seconds) async {
    if (!widget.canControl) return;
    final target = widget.player.state.position + Duration(seconds: seconds);
    await widget.onSeek(clampSeekPosition(widget.player, target));
  }

  Future<void> _toggleMute() async {
    final settings = SettingsService.instance;
    final volume = widget.player.state.volume;
    final newVolume = volume == 0 ? settings.read(SettingsService.maxVolume).toDouble() : 0.0;
    await widget.player.setVolume(newVolume);
    await settings.write(SettingsService.volume, newVolume);
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopPipService.isSupported) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: DesktopPipService.isActive,
      builder: (context, isActive, child) {
        if (!isActive) return const SizedBox.shrink();

        return Positioned.fill(
          child: DragToResizeArea(
            resizeEdgeSize: 10,
            child: Shortcuts(
              shortcuts: {
                const SingleActivator(LogicalKeyboardKey.escape): const _ExitDesktopPipIntent(),
                const SingleActivator(LogicalKeyboardKey.space): const _PipPlayPauseIntent(),
                const SingleActivator(LogicalKeyboardKey.arrowLeft): const _PipSeekBackIntent(),
                const SingleActivator(LogicalKeyboardKey.arrowRight): const _PipSeekForwardIntent(),
              },
              child: Actions(
                actions: {
                  _ExitDesktopPipIntent: CallbackAction<_ExitDesktopPipIntent>(
                    onInvoke: (_) {
                      widget.onExitPip();
                      return null;
                    },
                  ),
                  _PipPlayPauseIntent: CallbackAction<_PipPlayPauseIntent>(
                    onInvoke: (_) {
                      if (widget.canControl) widget.onPlayPause();
                      return null;
                    },
                  ),
                  _PipSeekBackIntent: CallbackAction<_PipSeekBackIntent>(
                    onInvoke: (_) {
                      unawaited(_seekByOffset(-_seekTimeSmall));
                      return null;
                    },
                  ),
                  _PipSeekForwardIntent: CallbackAction<_PipSeekForwardIntent>(
                    onInvoke: (_) {
                      unawaited(_seekByOffset(_seekTimeSmall));
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hovering = true),
                    onExit: (_) {
                      if (!_scrubbing) setState(() => _hovering = false);
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (_) => DesktopPipService.startDragging(),
                            onDoubleTap: widget.onExitPip,
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: IgnorePointer(
                            ignoring: !_controlsVisible,
                            child: AnimatedOpacity(
                              opacity: _controlsVisible ? 1 : 0,
                              duration: const Duration(milliseconds: 150),
                              child: _PipGlassControls(
                                player: widget.player,
                                canControl: widget.canControl,
                                isLive: widget.isLive,
                                seekTimeSmall: _seekTimeSmall,
                                scrubPreviewPosition: _scrubPreviewPosition,
                                onExitPip: widget.onExitPip,
                                onPlayPause: widget.onPlayPause,
                                onToggleMute: _toggleMute,
                                onSeekBackward: () => unawaited(_seekByOffset(-_seekTimeSmall)),
                                onSeekForward: () => unawaited(_seekByOffset(_seekTimeSmall)),
                                onScrubStart: () => setState(() => _scrubbing = true),
                                onScrubEnd: (position) {
                                  setState(() {
                                    _scrubbing = false;
                                    _scrubPreviewPosition = null;
                                  });
                                  unawaited(widget.onSeek(position));
                                },
                                onScrub: (position) => setState(() => _scrubPreviewPosition = position),
                                onPointerEnter: () => setState(() => _hovering = true),
                                onPointerExit: () {
                                  if (!_scrubbing) setState(() => _hovering = false);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PipGlassControls extends StatelessWidget {
  const _PipGlassControls({
    required this.player,
    required this.canControl,
    required this.isLive,
    required this.seekTimeSmall,
    required this.onExitPip,
    required this.onPlayPause,
    required this.onToggleMute,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onScrubStart,
    required this.onScrubEnd,
    required this.onScrub,
    required this.onPointerEnter,
    required this.onPointerExit,
    this.scrubPreviewPosition,
  });

  final Player player;
  final bool canControl;
  final bool isLive;
  final int seekTimeSmall;
  final Duration? scrubPreviewPosition;
  final VoidCallback onExitPip;
  final VoidCallback onPlayPause;
  final Future<void> Function() onToggleMute;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onScrubStart;
  final ValueChanged<Duration> onScrubEnd;
  final ValueChanged<Duration> onScrub;
  final VoidCallback onPointerEnter;
  final VoidCallback onPointerExit;

  static const _buttonSize = 36.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onPointerEnter(),
      onExit: (_) => onPointerExit(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLive)
            EmbyPlayerGlassBar(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minHeight: kEmbyPlayerScrubberBarHeight,
              child: VideoTimelineBar(
                player: player,
                chapters: const [],
                chaptersLoaded: true,
                showChapterMarkersOnTimeline: false,
                onSeek: onScrub,
                onSeekEnd: onScrubEnd,
                onScrubStart: onScrubStart,
                horizontalLayout: true,
                enabled: canControl,
                previewPosition: scrubPreviewPosition,
              ),
            ),
          if (!isLive) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: EmbyPlayerGlassBar(
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isLive) ...[
                        _transportButton(
                          icon: getReplayIcon(seekTimeSmall),
                          label: t.videoControls.seekBackwardButton(seconds: seekTimeSmall),
                          onPressed: canControl ? onSeekBackward : null,
                        ),
                      ],
                      PlayPauseStreamBuilder(
                        player: player,
                        builder: (context, isPlaying) {
                          return _transportButton(
                            icon: isPlaying ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
                            label: isPlaying ? t.videoControls.pauseButton : t.videoControls.playButton,
                            onPressed: canControl ? onPlayPause : null,
                            iconSize: 22,
                          );
                        },
                      ),
                      if (!isLive) ...[
                        _transportButton(
                          icon: getForwardIcon(seekTimeSmall),
                          label: t.videoControls.seekForwardButton(seconds: seekTimeSmall),
                          onPressed: canControl ? onSeekForward : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              EmbyPlayerGlassBar(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: StreamBuilder<double>(
                  stream: player.streams.volume,
                  initialData: player.state.volume,
                  builder: (context, snapshot) {
                    final volume = snapshot.data ?? 100.0;
                    final isMuted = volume == 0;
                    return _transportButton(
                      icon: isMuted ? Symbols.volume_off_rounded : Symbols.volume_up_rounded,
                      label: isMuted ? t.videoControls.unmuteButton : t.videoControls.muteButton,
                      onPressed: canControl ? () => unawaited(onToggleMute()) : null,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              EmbyPlayerGlassBar(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: _transportButton(
                  icon: Symbols.close_rounded,
                  label: t.videoControls.exitPipButton,
                  onPressed: onExitPip,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transportButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    double iconSize = _iconSize,
  }) {
    return EmbyPlayerGlassIconButton(
      semanticLabel: label,
      tooltip: label,
      icon: icon,
      iconSize: iconSize,
      size: _buttonSize,
      onPressed: onPressed,
    );
  }
}

class _ExitDesktopPipIntent extends Intent {
  const _ExitDesktopPipIntent();
}

class _PipPlayPauseIntent extends Intent {
  const _PipPlayPauseIntent();
}

class _PipSeekBackIntent extends Intent {
  const _PipSeekBackIntent();
}

class _PipSeekForwardIntent extends Intent {
  const _PipSeekForwardIntent();
}
