import 'package:flutter/material.dart';
import 'package:emby_player/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../focus/focusable_wrapper.dart';
import '../../i18n/strings.g.dart';
import '../../media/media_backend.dart';
import '../../theme/mono_tokens.dart';
import '../../profiles/profile.dart';
import '../../widgets/backend_badge.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../profile/borrow_connection_screen.dart';
import 'add_emby_server_screen.dart';
import 'add_jellyfin_screen.dart';

/// Picker shown when the user taps "Add connection".
class AddConnectionScreen extends StatelessWidget {
  final Profile? targetProfile;

  const AddConnectionScreen({super.key, this.targetProfile});

  @override
  Widget build(BuildContext context) {
    final scoped = targetProfile != null;
    final options = <_BackendOption>[
      _BackendOption(
        backend: MediaBackend.emby,
        title: 'Connect to Emby Server',
        subtitle: scoped
            ? 'Add an Emby server for ${targetProfile!.displayName}'
            : 'Sign in with your Emby server URL and credentials',
        builder: (_) => AddEmbyScreen(targetProfile: targetProfile),
      ),
      _BackendOption(
        backend: MediaBackend.jellyfin,
        title: t.addServer.connectToJellyfinCard,
        subtitle: scoped
            ? t.addServer.connectToJellyfinCardSubtitleScoped(name: targetProfile!.displayName)
            : t.addServer.connectToJellyfinCardSubtitle,
        builder: (_) => AddJellyfinScreen(targetProfile: targetProfile),
      ),
      if (scoped)
        _BackendOption(
          backend: null,
          title: t.addServer.borrowFromAnotherProfile,
          subtitle: t.addServer.borrowFromAnotherProfileSubtitle,
          builder: (_) => BorrowConnectionScreen(targetProfile: targetProfile!),
        ),
    ];
    final tokensRef = tokens(context);
    BorderRadius radiiFor(int i) => BorderRadius.vertical(
      top: Radius.circular(i == 0 ? tokensRef.radiusLg : tokensRef.radiusXs),
      bottom: Radius.circular(i == options.length - 1 ? tokensRef.radiusLg : tokensRef.radiusXs),
    );
    return FocusedScrollScaffold(
      title: Text(
        scoped
            ? t.addServer.addConnectionTitleScoped(name: targetProfile!.displayName)
            : t.addServer.addConnectionTitle,
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) SizedBox(height: tokensRef.groupGap),
                _BackendCard(
                  borderRadius: radiiFor(i),
                  leading: options[i].backend != null
                      ? BackendBadge(backend: options[i].backend!, size: 28)
                      : const AppIcon(Symbols.share_rounded, fill: 1, size: 28),
                  title: options[i].title,
                  subtitle: options[i].subtitle,
                  onTap: () async {
                    final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: options[i].builder));
                    if (added == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _BackendOption {
  final MediaBackend? backend;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;

  const _BackendOption({required this.backend, required this.title, required this.subtitle, required this.builder});
}

class _BackendCard extends StatelessWidget {
  final BorderRadius borderRadius;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BackendCard({
    required this.borderRadius,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusableWrapper(
      disableScale: true,
      borderRadii: borderRadius,
      descendantsAreFocusable: false,
      onSelect: onTap,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const AppIcon(Symbols.chevron_right_rounded, fill: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
