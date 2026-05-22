import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _NavItem {
  final String path;
  final IconData icon;
  final String label;

  const _NavItem(this.path, this.icon, this.label);
}

const _navItems = [
  _NavItem('/profile', Icons.person_outline, 'Perfil'),
  _NavItem('/certifications', Icons.school_outlined, 'Certificações'),
  _NavItem('/linkedin', Icons.bar_chart_outlined, 'LinkedIn'),
  _NavItem('/posts', Icons.article_outlined, 'Posts'),
  _NavItem('/narratives', Icons.record_voice_over_outlined, 'Narrativas'),
  _NavItem('/reviews', Icons.rate_review_outlined, 'Revisões'),
  _NavItem('/opportunities', Icons.work_outline, 'Oportunidades'),
  _NavItem('/networking', Icons.people_outline, 'Networking'),
  _NavItem('/events', Icons.event_outlined, 'Eventos'),
];

class ShellScaffold extends StatelessWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isWide,
            minWidth: 56,
            minExtendedWidth: 220,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.primary.withOpacity(0.15),
            selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
            unselectedIconTheme: IconThemeData(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            selectedLabelTextStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 13,
            ),
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (i) => context.go(_navItems[i].path),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: isWide
                  ? Row(
                      children: [
                        const SizedBox(width: 16),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Metrifica',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt, color: Colors.white, size: 18),
                    ),
            ),
            destinations: _navItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          VerticalDivider(
            width: 1,
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    for (var i = 0; i < _navItems.length; i++) {
      if (location.startsWith(_navItems[i].path)) return i;
    }
    return 0;
  }
}
