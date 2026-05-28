import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/flow_model.dart';
import '../../core/models/module_model.dart';
import '../../core/models/organization_model.dart';
import '../../core/models/squad_definition_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/organization_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/repositories/flows_repository.dart';
import '../../core/repositories/modules_repository.dart';
import '../../core/repositories/squads_repository.dart';
import '../../core/supabase/supabase_client.dart';

class ShellScaffold extends ConsumerWidget {
  final Widget child;
  const ShellScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = GoRouterState.of(context).uri;
    final location = uri.path;
    final currentFlowHint = uri.queryParameters['flow'];
    final isWide = MediaQuery.of(context).size.width > 960;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            isWide: isWide,
            location: location,
            currentFlowHint: currentFlowHint,
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
}

class _Sidebar extends ConsumerWidget {
  final bool isWide;
  final String location;
  final String? currentFlowHint;

  const _Sidebar({
    required this.isWide,
    required this.location,
    required this.currentFlowHint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarBg =
        isDark ? const Color(0xFF0C0C12) : const Color(0xFFF8FAFC);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.outlineVariant;

    final flowsAsync = ref.watch(flowsProvider);
    final modulesAsync = ref.watch(modulesProvider);
    final squadsAsync = ref.watch(squadsProvider);
    final org = ref.watch(activeOrgProvider);
    final enabledFlowSlugs = ref.watch(orgEnabledFlowSlugsProvider).valueOrNull;
    final enabledModuleSlugs =
        ref.watch(orgEnabledModuleSlugsProvider).valueOrNull;
    final width = isWide ? 220.0 : 68.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: width,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(
          right: BorderSide(color: dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Logo(isWide: isWide, org: org),
          Divider(
              color: dividerColor,
              height: 1,
              indent: isWide ? 20 : 12,
              endIndent: isWide ? 20 : 12),
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
                    org: org,
                    enabledFlowSlugs: enabledFlowSlugs,
                    enabledModuleSlugs: enabledModuleSlugs,
                    location: location,
                    currentFlowHint: currentFlowHint,
                    isWide: isWide,
                  ),
                  error: (_, __) => _NavList(
                    flows: flows,
                    modules: modules,
                    squads: const [],
                    org: org,
                    enabledFlowSlugs: enabledFlowSlugs,
                    enabledModuleSlugs: enabledModuleSlugs,
                    location: location,
                    currentFlowHint: currentFlowHint,
                    isWide: isWide,
                  ),
                  data: (squads) => _NavList(
                    flows: flows,
                    modules: modules,
                    squads: squads,
                    org: org,
                    enabledFlowSlugs: enabledFlowSlugs,
                    enabledModuleSlugs: enabledModuleSlugs,
                    location: location,
                    currentFlowHint: currentFlowHint,
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
  final OrganizationModel? org;
  final Set<String>? enabledFlowSlugs;
  final Set<String>? enabledModuleSlugs;
  final String location;
  final String? currentFlowHint;
  final bool isWide;

  const _NavList({
    required this.flows,
    required this.modules,
    required this.squads,
    required this.org,
    required this.enabledFlowSlugs,
    required this.enabledModuleSlugs,
    required this.location,
    required this.currentFlowHint,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final moduleMap = {for (final m in modules) m.slug: m};

    final visibleFlows = enabledFlowSlugs == null
        ? flows
        : flows.where((f) => enabledFlowSlugs!.contains(f.slug)).toList();

    final openFlowSlug = _openFlowSlugForLocation(
      location: location,
      flows: visibleFlows,
      enabledModuleSlugs: enabledModuleSlugs,
      currentFlowHint: currentFlowHint,
    );

    final showSquads = org?.hasFeature('squad') ?? true;

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8),
      children: [
        ...visibleFlows.map((flow) => _FlowSection(
              flow: flow,
              moduleMap: moduleMap,
              enabledModuleSlugs: enabledModuleSlugs,
              location: location,
              isExpanded: openFlowSlug == flow.slug,
              isWide: isWide,
            )),
        if (showSquads && squads.isNotEmpty) ...[
          if (isWide)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(
                'SQUADS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: onSurface.withValues(alpha: 0.25),
                  letterSpacing: 1.2,
                ),
              ),
            )
          else
            Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : theme.colorScheme.outlineVariant,
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

  String? _openFlowSlugForLocation({
    required String location,
    required List<FlowModel> flows,
    required Set<String>? enabledModuleSlugs,
    required String? currentFlowHint,
  }) {
    if (location.startsWith('/flows/')) {
      final slug = location.substring('/flows/'.length);
      return flows.any((f) => f.slug == slug) ? slug : null;
    }

    if (!location.startsWith('/modules/')) return null;
    final moduleSlug = location.substring('/modules/'.length);

    if (currentFlowHint != null) {
      final hintedFlow =
          flows.where((f) => f.slug == currentFlowHint).firstOrNull;
      if (hintedFlow != null) {
        final visibleModules = enabledModuleSlugs == null
            ? hintedFlow.moduleSlugs
            : hintedFlow.moduleSlugs
                .where(enabledModuleSlugs.contains)
                .toList();
        if (visibleModules.contains(moduleSlug)) return hintedFlow.slug;
      }
    }

    for (final flow in flows) {
      final visibleModules = enabledModuleSlugs == null
          ? flow.moduleSlugs
          : flow.moduleSlugs.where(enabledModuleSlugs.contains).toList();
      if (visibleModules.contains(moduleSlug)) return flow.slug;
    }

    return null;
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final active = location == '/squads/${squad.slug}';

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
          color: active ? primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: () => context.go('/squads/${squad.slug}'),
          borderRadius: BorderRadius.circular(8),
          hoverColor: onSurface.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 15,
                  color: active ? primary : onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    squad.name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? onSurface.withValues(alpha: 0.85)
                          : onSurface.withValues(alpha: 0.35),
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

class _FlowSection extends StatelessWidget {
  final FlowModel flow;
  final Map<String, ModuleModel> moduleMap;
  final Set<String>? enabledModuleSlugs;
  final String location;
  final bool isExpanded;
  final bool isWide;

  const _FlowSection({
    required this.flow,
    required this.moduleMap,
    required this.enabledModuleSlugs,
    required this.location,
    required this.isExpanded,
    required this.isWide,
  });

  bool get _isActive {
    return isExpanded;
  }

  List<String> get _visibleModuleSlugs {
    final enabled = enabledModuleSlugs;
    if (enabled == null) return flow.moduleSlugs;
    return flow.moduleSlugs.where(enabled.contains).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final active = _isActive;
    final visibleSlugs = _visibleModuleSlugs;

    if (!isWide) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Tooltip(
          message: flow.name,
          child: _NavTileCompact(
            icon: Icons.account_tree_outlined,
            selected: active,
            onTap: () => context.go('/flows/${flow.slug}'),
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
            onTap: () => context.go('/flows/${flow.slug}'),
            borderRadius: BorderRadius.circular(8),
            hoverColor: onSurface.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 15,
                    color: active ? primary : onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      flow.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? onSurface.withValues(alpha: 0.85)
                            : onSurface.withValues(alpha: 0.35),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: active && visibleSlugs.isNotEmpty
              ? Padding(
                  key: ValueKey(flow.slug),
                  padding: const EdgeInsets.only(left: 8, bottom: 4, top: 2),
                  child: Column(
                    children: visibleSlugs.map((slug) {
                      final module = moduleMap[slug];
                      final name = module?.name ?? slug;
                      final selected = location == '/modules/$slug';
                      return _ModuleNavTile(
                        name: name,
                        selected: selected,
                        onTap: () =>
                            context.go('/modules/$slug?flow=${flow.slug}'),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('collapsed')),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: onSurface.withValues(alpha: 0.04),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                selected ? primary.withValues(alpha: 0.12) : Colors.transparent,
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
                  color: selected ? primary : onSurface.withValues(alpha: 0.2),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? onSurface.withValues(alpha: 0.9)
                        : onSurface.withValues(alpha: 0.45),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

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
            color:
                selected ? primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              size: 18,
              color: selected ? primary : onSurface.withValues(alpha: 0.45)),
        ),
      ),
    );
  }
}

class _Logo extends ConsumerWidget {
  final bool isWide;
  final OrganizationModel? org;
  const _Logo({required this.isWide, required this.org});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final orgName = org?.name ?? 'Platform';

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orgName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Platform',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onSurface.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
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
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.outlineVariant;

    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '';
    final initials = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final orgsAsync = ref.watch(userOrgsProvider);
    final activeOrg = ref.watch(activeOrgProvider);

    Future<void> signOut() async {
      await supabase.auth.signOut();
      if (context.mounted) context.go('/login');
    }

    void toggleTheme() {
      ref.read(themeModeProvider.notifier).toggleTheme();
    }

    final themeMode = ref.watch(themeModeProvider);
    final orgs = orgsAsync.valueOrNull ?? [];
    final hasMultipleOrgs = orgs.length > 1;

    return Column(
      children: [
        Divider(
          color: dividerColor,
          height: 1,
          indent: isWide ? 20 : 12,
          endIndent: isWide ? 20 : 12,
        ),
        if (isWide && hasMultipleOrgs)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: PopupMenuButton<OrganizationModel>(
              onSelected: (org) =>
                  ref.read(activeOrgProvider.notifier).setOrg(org),
              itemBuilder: (_) => orgs
                  .map(
                    (org) => PopupMenuItem(
                      value: org,
                      child: Row(
                        children: [
                          if (org.id == activeOrg?.id)
                            Icon(Icons.check,
                                size: 14, color: theme.colorScheme.primary)
                          else
                            const SizedBox(width: 14),
                          const SizedBox(width: 8),
                          Text(org.name, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business_outlined,
                        size: 13, color: onSurface.withValues(alpha: 0.35)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        activeOrg?.name ?? '—',
                        style: TextStyle(
                          fontSize: 11,
                          color: onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.unfold_more,
                        size: 13, color: onSurface.withValues(alpha: 0.25)),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(isWide ? 12 : 10, 14, 12, 20),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                      color: onSurface.withValues(alpha: 0.4),
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Tooltip(
                message:
                    themeMode == ThemeMode.dark ? 'Tema claro' : 'Tema escuro',
                child: InkWell(
                  onTap: toggleTheme,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 15,
                      color: onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Sair',
                child: InkWell(
                  onTap: signOut,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.logout_rounded,
                        size: 15, color: onSurface.withValues(alpha: 0.3)),
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
