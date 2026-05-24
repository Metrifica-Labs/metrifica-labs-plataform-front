import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/flow_model.dart';
import '../../core/models/module_model.dart';
import '../../core/models/squad_definition_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/flows_repository.dart';
import '../../core/repositories/modules_repository.dart';
import '../../core/repositories/squads_repository.dart';
import '../../core/supabase/supabase_client.dart';

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
    final squadsAsync = ref.watch(squadsProvider);
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
                data: (modules) => squadsAsync.when(
                  loading: () => _NavList(
                    flows: flows,
                    modules: modules,
                    squads: const [],
                    location: location,
                    isWide: isWide,
                  ),
                  error: (_, __) => _NavList(
                    flows: flows,
                    modules: modules,
                    squads: const [],
                    location: location,
                    isWide: isWide,
                  ),
                  data: (squads) => _NavList(
                    flows: flows,
                    modules: modules,
                    squads: squads,
                    location: location,
                    isWide: isWide,
                  ),
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
  final List<SquadDefinitionModel> squads;
  final String location;
  final bool isWide;

  const _NavList({
    required this.flows,
    required this.modules,
    required this.squads,
    required this.location,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final moduleMap = {for (final m in modules) m.slug: m};

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8),
      children: [
        ...flows.map((flow) => _FlowSection(
              flow: flow,
              moduleMap: moduleMap,
              location: location,
              isWide: isWide,
            )),
        if (squads.isNotEmpty) ...[
          if (isWide)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(
                'SQUADS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.2),
                  letterSpacing: 1.2,
                ),
              ),
            )
          else
            Divider(
              color: Colors.white.withValues(alpha: 0.06),
              height: 16,
            ),
          ...squads.map((squad) => _SquadNavTile(
                squad: squad,
                location: location,
                isWide: isWide,
              )),
        ],
      ],
    );
  }
}

class _SquadNavTile extends StatelessWidget {
  final SquadDefinitionModel squad;
  final String location;
  final bool isWide;

  const _SquadNavTile({
    required this.squad,
    required this.location,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final active = location == '/squads/${squad.slug}';
    final primary = Theme.of(context).colorScheme.primary;

    if (!isWide) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Tooltip(
          message: squad.name,
          child: _NavTileCompact(
            icon: Icons.groups_2_outlined,
            selected: active,
            onTap: () => context.go('/squads/${squad.slug}'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () => context.go('/squads/${squad.slug}'),
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 15,
                  color: active
                      ? primary
                      : Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    squad.name,
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
              ],
            ),
          ),
        ),
      ),
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
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: active ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: InkWell(
            onTap: () => context.go('/flows/${widget.flow.slug}'),
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.white.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 15,
                    color: active ? primary : Colors.white.withValues(alpha: 0.3),
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
                  // chevron separado — só expande/colapsa
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              ),
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

class _Footer extends ConsumerWidget {
  final bool isWide;
  const _Footer({required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';

    Future<void> signOut() async {
      await supabase.auth.signOut();
      if (context.mounted) context.go('/login');
    }

    return Column(
      children: [
        Divider(
          color: Colors.white.withValues(alpha: 0.06),
          height: 1,
          indent: isWide ? 20 : 12,
          endIndent: isWide ? 20 : 12,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 12 : 10, 14, 12, 20),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      )),
                ),
              ),
              if (isWide) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Tooltip(
                message: 'Sair',
                child: InkWell(
                  onTap: signOut,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.logout_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
