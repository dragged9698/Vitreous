import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';
import '../theme/emby_glass_theme.dart';
import 'ios_status_bar_tap_scroll_to_top.dart';

/// Glass navigation chrome + opaque scroll body (settings, about, etc.).
class EmbyGlassScrollScaffold extends StatefulWidget {
  const EmbyGlassScrollScaffold({
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
  State<EmbyGlassScrollScaffold> createState() => _EmbyGlassScrollScaffoldState();
}

class _EmbyGlassScrollScaffoldState extends State<EmbyGlassScrollScaffold> {
  final _scopeNode = FocusScopeNode();
  final _scrollController = ScrollController();
  bool _focusRequested = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _scopeNode.dispose();
    super.dispose();
  }

  void _requestInitialFocus() {
    if (_focusRequested || !mounted || !InputModeTracker.isKeyboardMode(context)) return;
    _focusRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scopeNode.focusedChild != null) return;
      _scopeNode.requestFocus();
      _scopeNode.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_focusRequested && InputModeTracker.isKeyboardMode(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _requestInitialFocus());
    }

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (widget.onBackPressed != null) {
          return handleBackKeyAction(event, widget.onBackPressed!);
        }
        return handleBackKeyNavigation(context, event);
      },
      child: FocusScope(
        node: _scopeNode,
        child: IosStatusBarTapScrollToTop(
          child: GlassScaffold(
            background: embyAppBackdrop(context),
            contentAwareBrightness: true,
            statusBarStyle: GlassStatusBarStyle.auto,
            appBar: GlassAppBar(
              title: widget.title,
              leading: widget.automaticallyImplyLeading && Navigator.of(context).canPop()
                  ? GlassIconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () {
                        if (widget.onBackPressed != null) {
                          widget.onBackPressed!();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                    )
                  : null,
              actions: widget.actions,
            ),
            body: CustomScrollView(controller: _scrollController, slivers: widget.slivers),
          ),
        ),
      ),
    );
  }
}
