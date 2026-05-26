import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/repositories/flows_repository.dart';
import '../../../core/repositories/modules_repository.dart';
import '../../generation/presentation/generation_panel.dart';

class FlowPage extends ConsumerWidget {
  final String slug;
  const FlowPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowAsync = ref.watch(flowBySlugProvider(slug));
    final modulesAsync = ref.watch(modulesProvider);

    return flowAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (flow) {
        if (flow == null) {
          return const Center(child: Text('Flow não encontrado.'));
        }
        return modulesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (allModules) {
            final moduleMap = {for (final m in allModules) m.slug: m};

            return SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Cabeçalho ────────────────────────────────────────
                  Text(
                    flow.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ),
                  if (flow.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      flow.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.6,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // ── Lista de módulos ──────────────────────────────────
                  Text(
                    '${flow.moduleSlugs.length} módulos neste flow',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(flow.moduleSlugs.length, (i) {
                    final s = flow.moduleSlugs[i];
                    final m = moduleMap[s];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ModuleTile(
                        index: i + 1,
                        slug: s,
                        name: m?.name ?? s,
                        moduleRef: m?.moduleRef,
                        onTap: () => context.go('/modules/$s'),
                      ),
                    );
                  }),

                  const SizedBox(height: 32),

                  // ── Painel de geração ─────────────────────────────────
                  GenerationPanel(flowSlug: flow.slug),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final int index;
  final String slug;
  final String name;
  final String? moduleRef;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.index,
    required this.slug,
    required this.name,
    this.moduleRef,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    if (moduleRef != null)
                      Text(
                        'Módulo $moduleRef',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: Colors.white.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }
}
