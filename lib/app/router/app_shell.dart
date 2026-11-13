import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive/window_size.dart';
import '../../core/theme/app_spacing.dart';

/// Adaptive navigation for the five tabs:
/// - compact: bottom [NavigationBar]
/// - medium / expanded: [NavigationRail] with labels
/// - large: extended rail showing labels beside icons
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const destinations = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Brain'),
    (Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Capture'),
    (Icons.psychology_alt_outlined, Icons.psychology_alt_rounded, 'Ask'),
    (Icons.search_rounded, Icons.manage_search_rounded, 'Search'),
  ];

  static const _extendedRailWidth = 200.0;
  static const _logoSize = 32.0;

  /// Re-selecting the current tab returns it to its root.
  void _goTo(int index) => shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    if (size.isCompact) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _goTo,
          destinations: [
            for (final (icon, selected, label) in destinations)
              NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
          ],
        ),
      );
    }
    final extended = size == WindowSize.large;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: _extendedRailWidth,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _goTo,
              labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: _logoSize,
                      color: theme.colorScheme.primary,
                    ),
                    if (extended) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text('Pocket Brain', style: theme.textTheme.titleMedium),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final (icon, selected, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    selectedIcon: Icon(selected),
                    label: Text(label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      ),
    );
  }
}
