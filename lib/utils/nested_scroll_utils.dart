import 'package:flutter/material.dart';

/// True when [context] sits under a [NestedScrollView] header absorber.
bool isInsideNestedScrollView(BuildContext context) {
  return context.findAncestorWidgetOfExactType<NestedScrollView>() != null;
}

/// Overlap injector for library tabs embedded in [NestedScrollView] mobile chrome.
///
/// Side-navigation layout uses a [Column] toolbar instead — injecting without a
/// [NestedScrollView] ancestor throws in debug.
List<Widget> nestedScrollOverlapSlivers(BuildContext context) {
  if (!isInsideNestedScrollView(context)) return const [];
  return [
    SliverOverlapInjector(
      handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
    ),
  ];
}
