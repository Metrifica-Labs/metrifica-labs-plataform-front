import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/squads_repository.dart';
import 'squad_calibration_panel.dart';
import 'squad_history_panel.dart';
import 'squad_run_panel.dart';

class SquadPage extends ConsumerStatefulWidget {
  final String slug;
  const SquadPage({super.key, required this.slug});

  @override
  ConsumerState<SquadPage> createState() => _SquadPageState();
}

class _SquadPageState extends ConsumerState<SquadPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(squadBySlugProvider(widget.slug));

    return squadAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (err, _) => Center(
        child: Text(
          'Erro ao carregar squad',
          style: TextStyle(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      data: (squad) {
        if (squad == null) {
          final onSurface = Theme.of(context).colorScheme.onSurface;
          return Center(
            child: Text(
              'Squad não encontrada',
              style: TextStyle(color: onSurface.withValues(alpha: 0.6)),
            ),
          );
        }
        final onSurface = Theme.of(context).colorScheme.onSurface;
        final outline = Theme.of(context).colorScheme.outline;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Squad',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.secondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${squad.agentSlugs.length} agentes',
                        style: TextStyle(
                          fontSize: 11,
                          color: onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    squad.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                  ),
                  if (squad.description != null &&
                      squad.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      squad.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Tabs ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _TabButton(
                    label: 'Execução',
                    icon: Icons.play_circle_outline,
                    active: _tabs.index == 0,
                    onTap: () => _tabs.animateTo(0),
                  ),
                  const SizedBox(width: 4),
                  _TabButton(
                    label: 'Calibração',
                    icon: Icons.checklist_rtl,
                    active: _tabs.index == 1,
                    onTap: () => _tabs.animateTo(1),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => showSquadHistoryPanel(context),
                    icon: const Icon(Icons.history, size: 14),
                    label: const Text('Histórico'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: onSurface.withValues(alpha: 0.75),
                      side: BorderSide(color: outline.withValues(alpha: 0.7)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

            Divider(
                height: 1,
                color: outline.withValues(alpha: 0.5),
                indent: 0,
                endIndent: 0),

            // ── Conteúdo das tabs ────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SquadRunPanel(squadSlug: widget.slug),
                  SquadCalibrationPanel(squad: squad),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final color = active
        ? onSurface.withValues(alpha: 0.92)
        : onSurface.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              active ? onSurface.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? outline.withValues(alpha: 0.7) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
