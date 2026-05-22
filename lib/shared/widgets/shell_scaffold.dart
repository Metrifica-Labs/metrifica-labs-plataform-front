import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/flow_model.dart';
import '../../core/models/module_model.dart';
import '../../core/repositories/flows_repository.dart';
import '../../core/repositories/modules_repository.dart';

const _sidebarBg = Color(0xFF0C0C12);

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final isWide = MediaQuery.of(context).size.width > 960;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(isWide: isWide, location: location),
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
}

class _Sidebar extends ConsumerWidget {
  final bool isWide;
  final String location;

  const _Sidebar({required this.isWide, required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowsAsync = ref.watch(flowsProvider);
    final modulesAsync = ref.watch(modulesProvider);
    final width = isWide ? 220.0 : 68.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: width,
      color: _sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Logo(isWide: isWide),
          Divider(
            color: Colors.white.withValues(alpha: 0.06),
            height: 1,
            indent: isWide ? 20 : 12,
            endIndent: isWide ? 20 : 12,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: flowsAsync.when(
              loading: () => const Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5))),
              error: (_, __) => const SizedBox.shrink(),
              data: (flows) => modulesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (modules) => _NavList(
                  flows: flows,
                  modules: modules,
                  location: location,
                  isWide: isWide,
                ),
              ),
            ),
          ),
          _Footer(isWide: isWide),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  final List<FlowModel> flows;
  final List<ModuleModel> modules;
  final String location;
  final bool isWide;

  const _NavList({
    required this.flows,
    required this.modules,
    required this.location,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final moduleMap = {for (final m in modules) m.slug: m};

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8),
      children: flows.map((flow) {
        return _FlowSection(
          flow: flow,
          moduleMap: moduleMap,
          location: location,
          isWide: isWide,
        );
      }).toList(),
    );
  }
}

class _FlowSection extends StatefulWidget {
  final FlowModel flow;
  final Map<String, ModuleModel> moduleMap;
  final String location;
  final bool isWide;

  const _FlowSection({
    required this.flow,
    required this.moduleMap,
    required this.location,
    required this.isWide,
  });

  @override
  State<_FlowSection> createState() => _FlowSectionState();
}

class _FlowSectionState extends State<_FlowSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _isActive;
  }

  bool get _isActive {
    final loc = widget.location;
    if (loc == '/flows/${widget.flow.slug}') return true;
    return widget.flow.moduleSlugs.any((s) => loc == '/modules/$s');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final active = _isActive;

    if (!widget.isWide) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Tooltip(
          message: widget.flow.name,
          child: _NavTileCompact(
            icon: Icons.account_tree_outlined,
            selected: active,
            onTap: () => context.go('/flows/${widget.flow.slug}'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
          },
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: active
                  ? primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 15,
                  color: active
                      ? primary
                      : Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.flow.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Column(
              children: widget.flow.moduleSlugs.map((slug) {
                final module = widget.moduleMap[slug];
                final name = module?.name ?? slug;
                final selected = widget.location == '/modules/$slug';
                return _ModuleNavTile(
                  name: name,
                  selected: selected,
                  onTap: () => context.go('/modules/$slug'),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _ModuleNavTile extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _ModuleNavTile({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? primary
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTileCompact extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavTileCompact({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          width: 40,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: selected ? primary : Colors.white.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final bool isWide;
  const _Logo({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
            child:
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
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
    );
  }
}

class _Footer extends StatelessWidget {
  final bool isWide;
  const _Footer({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
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
    );
  }
}
