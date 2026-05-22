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

const _sidebarBg = Color(0xFF0C0C12);

class ShellScaffold extends StatelessWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final isWide = MediaQuery.of(context).size.width > 960;
    final selectedIndex = _selectedIndex(location);

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            isWide: isWide,
            selectedIndex: selectedIndex,
            onSelect: (i) => context.go(_navItems[i].path),
          ),
          Expanded(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          ),
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

class _Sidebar extends StatelessWidget {
  final bool isWide;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.isWide,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = isWide ? 220.0 : 68.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: width,
      color: _sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: EdgeInsets.fromLTRB(isWide ? 20 : 14, 28, 16, 24),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                ),
                if (isWide) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metrifica',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          )),
                      Text('Platform',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.35),
                            letterSpacing: 0.5,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Divider sutil
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
            indent: isWide ? 20 : 12,
            endIndent: isWide ? 20 : 12,
          ),
          const SizedBox(height: 12),

          // Nav items
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8),
              child: Column(
                children: List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final selected = i == selectedIndex;
                  return _NavTile(
                    item: item,
                    selected: selected,
                    isWide: isWide,
                    onTap: () => onSelect(i),
                  );
                }),
              ),
            ),
          ),

          // Rodapé
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
            indent: isWide ? 20 : 12,
            endIndent: isWide ? 20 : 12,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isWide ? 20 : 14, 16, 16, 24),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline,
                      size: 16, color: Colors.white.withValues(alpha: 0.5)),
                ),
                if (isWide) ...[
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Admin',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          )),
                      Text('metrifica-plataform',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool isWide;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.isWide,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          splashColor: primary.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 10),
            decoration: BoxDecoration(
              color: selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected
                      ? primary
                      : Colors.white.withValues(alpha: 0.45),
                ),
                if (isWide) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.92)
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
