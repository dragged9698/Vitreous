import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/emby_glass_theme.dart';
import 'app_icon.dart';
import 'focusable_list_tile.dart';
import 'settings_section.dart';

/// Groups consecutive settings rows into [GlassGroupedSection] cards.
///
/// [SettingsSectionHeader] widgets split the flat [children] list into sections.
/// Non-tile widgets (segmented settings, dividers) pass through unchanged.
class EmbyGlassSettingsSliver extends StatelessWidget {
  const EmbyGlassSettingsSliver({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final groups = _groupSettingsChildren(children);
    final widgets = <Widget>[];

    for (final group in groups) {
      switch (group) {
        case _SettingsHeaderGroup(:final title):
          widgets.add(SettingsSectionHeader(title));
        case _SettingsTileGroup(:final tiles):
          if (tiles.isEmpty) continue;
          widgets.add(
            EmbyGlassGroupedSection(
              children: tiles,
            ),
          );
        case _SettingsPassthroughGroup(:final widget):
          widgets.add(widget);
      }
    }

    final list = SliverList(delegate: SliverChildListDelegate(widgets));
    if (padding == null) return list;
    return SliverPadding(padding: padding!, sliver: list);
  }
}

/// A single glass grouped card for settings rows.
class EmbyGlassGroupedSection extends StatelessWidget {
  const EmbyGlassGroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final glassChildren = children.map((child) => embySettingsRowToGlass(context, child)).toList();
    return GlassGroupedSection(
      header: header,
      footer: footer,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      useOwnLayer: true,
      quality: embyChromeGlassQuality(),
      settings: embyChromeGlassSettings(context),
      children: glassChildren,
    );
  }
}

/// Converts common settings row widgets to [GlassListTile].
Widget embySettingsRowToGlass(BuildContext context, Widget child) {
  if (child is GlassListTile) return child;
  if (child is FocusableListTile) {
    return GlassListTile(
      leading: child.leading,
      title: child.title ?? const SizedBox.shrink(),
      subtitle: child.subtitle,
      trailing: child.trailing ?? (child.onTap != null ? GlassListTile.chevron : null),
      onTap: child.enabled ? child.onTap : null,
      onLongPress: child.onLongPress,
    );
  }
  if (child is ListTile) {
    return GlassListTile(
      leading: child.leading,
      title: child.title ?? const SizedBox.shrink(),
      subtitle: child.subtitle,
      trailing: child.trailing ?? (child.onTap != null ? GlassListTile.chevron : null),
      onTap: child.enabled ? child.onTap : null,
      onLongPress: child.onLongPress,
    );
  }
  if (child is SwitchListTile) {
    return GlassListTile(
      leading: child.secondary,
      title: child.title ?? const SizedBox.shrink(),
      subtitle: child.subtitle,
      trailing: ExcludeFocus(
        child: Switch(
          value: child.value,
          onChanged: child.onChanged,
        ),
      ),
      onTap: child.onChanged == null ? null : () => child.onChanged!(!child.value),
    );
  }
  return child;
}

/// Standard navigation settings row with glass styling.
class EmbyGlassSettingsTile extends StatelessWidget {
  const EmbyGlassSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.focusNode,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return FocusableListTile(
      focusNode: focusNode,
      leading: AppIcon(icon, fill: 1),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const AppIcon(Symbols.chevron_right_rounded, fill: 1),
      onTap: onTap,
    );
  }
}

sealed class _SettingsGroup {}

final class _SettingsHeaderGroup extends _SettingsGroup {
  _SettingsHeaderGroup(this.title);
  final String title;
}

final class _SettingsTileGroup extends _SettingsGroup {
  _SettingsTileGroup(this.tiles);
  final List<Widget> tiles;
}

final class _SettingsPassthroughGroup extends _SettingsGroup {
  _SettingsPassthroughGroup(this.widget);
  final Widget widget;
}

List<_SettingsGroup> _groupSettingsChildren(List<Widget> children) {
  final groups = <_SettingsGroup>[];
  var pendingTiles = <Widget>[];

  void flushTiles() {
    if (pendingTiles.isEmpty) return;
    groups.add(_SettingsTileGroup(List<Widget>.from(pendingTiles)));
    pendingTiles = [];
  }

  for (final child in children) {
    if (child is SettingsSectionHeader) {
      flushTiles();
      groups.add(_SettingsHeaderGroup(child.title));
      continue;
    }
    if (_isSettingsTile(child)) {
      pendingTiles.add(child);
      continue;
    }
    flushTiles();
    groups.add(_SettingsPassthroughGroup(child));
  }
  flushTiles();
  return groups;
}

bool _isSettingsTile(Widget child) {
  return child is ListTile ||
      child is FocusableListTile ||
      child is SwitchListTile ||
      child is GlassListTile ||
      child is EmbyGlassSettingsTile;
}
