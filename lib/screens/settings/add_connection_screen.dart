import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:emby_player/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../focus/focusable_wrapper.dart';
import '../../i18n/strings.g.dart';
import '../../media/media_backend.dart';
import '../../profiles/profile.dart';
import '../../widgets/backend_badge.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../profile/borrow_connection_screen.dart';
import 'add_emby_server_screen.dart';

/// Picker shown when the user taps "Add connection" (Emby-only fork).
class AddConnectionScreen extends StatelessWidget {
  final Profile? targetProfile;

  const AddConnectionScreen({super.key, this.targetProfile});

  @override
  Widget build(BuildContext context) {
    final scoped = targetProfile != null;
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
              _BackendCard(
                leading: const BackendBadge(backend: MediaBackend.emby, size: 28),
                title: 'Connect to Emby Server',
                subtitle: scoped
                    ? 'Add an Emby server for ${targetProfile!.displayName}'
                    : 'Sign in with your Emby server URL and credentials',
                onTap: () async {
                  final added = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => AddEmbyScreen(targetProfile: targetProfile)),
                  );
                  if (added == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0),
              if (scoped) ...[
                const SizedBox(height: 12),
                _BackendCard(
                  leading: const AppIcon(Symbols.share_rounded, fill: 1, size: 28),
                  title: t.addServer.borrowFromAnotherProfile,
                  subtitle: t.addServer.borrowFromAnotherProfileSubtitle,
                  onTap: () async {
                    final added = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => BorrowConnectionScreen(targetProfile: targetProfile!)),
                    );
                    if (added == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                ).animate().fadeIn(duration: 280.ms, delay: 80.ms).slideY(begin: 0.04, end: 0),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _BackendCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BackendCard({required this.leading, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FocusableWrapper(
      disableScale: true,
      borderRadius: 12,
      descendantsAreFocusable: false,
      onSelect: onTap,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
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
