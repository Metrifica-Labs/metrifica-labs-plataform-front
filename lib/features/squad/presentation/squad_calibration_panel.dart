import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/squad_definition_model.dart';
import '../../../core/repositories/agent_definitions_repository.dart';
import '../data/calibration_notifier.dart';

class SquadCalibrationPanel extends ConsumerWidget {
  final SquadDefinitionModel squad;

  const SquadCalibrationPanel({super.key, required this.squad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync =
        ref.watch(agentsBySlugListProvider(squad.agentSlugs));
    final calibration = ref.watch(calibrationProvider);

    return agentsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (agents) {
        final allTools = agents
            .expand((a) => a.toolNames)
            .toSet()
            .toList();

        final allPassed = allTools.isNotEmpty &&
            allTools.every((t) =>
                calibration.resultFor(t).status == ToolTestStatus.pass);
        final anyFailed = allTools.any((t) =>
            calibration.resultFor(t).status == ToolTestStatus.fail);

        return Column(
          children: [
            // ── Barra de ação ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.06)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calibração de Tools',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Verifica se as ferramentas dos agentes estão funcionando antes de executar o squad.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (allTools.isNotEmpty) ...[
                    if (allPassed)
                      _StatusChip(
                          label: 'Tudo OK',
                          color: Colors.green,
                          icon: Icons.check_circle_outline)
                    else if (anyFailed)
                      _StatusChip(
                          label: 'Falhas detectadas',
                          color: Colors.red,
                          icon: Icons.error_outline)
                    else
                      _StatusChip(
                          label: 'Não verificado',
                          color: Colors.white,
                          icon: Icons.help_outline),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: calibration.isRunningAll
                          ? null
                          : () => ref
                              .read(calibrationProvider.notifier)
                              .testAll(allTools),
                      icon: calibration.isRunningAll
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.5),
                            )
                          : const Icon(Icons.play_arrow, size: 15),
                      label: Text(
                          calibration.isRunningAll ? 'Verificando...' : 'Verificar Todos'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Lista de agentes ──────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: agents.length,
                itemBuilder: (context, i) {
                  final agent = agents[i];
                  return _AgentCard(agent: agent);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends ConsumerWidget {
  final dynamic agent;

  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calibration = ref.watch(calibrationProvider);
    final toolNames = agent.toolNames as List<String>;
    final hasTools = toolNames.isNotEmpty;

    final agentStatus = hasTools
        ? _agentOverallStatus(toolNames, calibration)
        : ToolTestStatus.pass;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(
          color: _borderColor(agentStatus).withValues(alpha: 0.15),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do agente
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _ToolStatusIcon(status: agentStatus, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        agent.role as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    agent.llmModel as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (hasTools) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            ...toolNames.map(
              (tool) => _ToolRow(
                toolName: tool,
                result: calibration.resultFor(tool),
                onTest: () =>
                    ref.read(calibrationProvider.notifier).testTool(tool),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Sem tools externas — apenas geração de texto',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.25)),
              ),
            ),
        ],
      ),
    );
  }

  ToolTestStatus _agentOverallStatus(
      List<String> tools, CalibrationState state) {
    final results = tools.map((t) => state.resultFor(t).status).toList();
    if (results.any((s) => s == ToolTestStatus.fail)) return ToolTestStatus.fail;
    if (results.any((s) => s == ToolTestStatus.running)) return ToolTestStatus.running;
    if (results.every((s) => s == ToolTestStatus.pass)) return ToolTestStatus.pass;
    return ToolTestStatus.idle;
  }

  Color _borderColor(ToolTestStatus status) {
    switch (status) {
      case ToolTestStatus.pass:
        return Colors.green;
      case ToolTestStatus.fail:
        return Colors.red;
      case ToolTestStatus.running:
        return Colors.blue;
      case ToolTestStatus.idle:
        return Colors.white;
    }
  }
}

class _ToolRow extends StatelessWidget {
  final String toolName;
  final ToolTestResult result;
  final VoidCallback onTest;

  const _ToolRow({
    required this.toolName,
    required this.result,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = result.status == ToolTestStatus.running;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ToolStatusIcon(status: result.status, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toolName,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
              if (result.durationMs != null)
                Text(
                  '${result.durationMs}ms',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: isRunning ? null : onTest,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    foregroundColor: Colors.white.withValues(alpha: 0.5),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(isRunning ? 'Testando...' : 'Testar'),
                ),
              ),
            ],
          ),
          if (result.message != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4),
              child: Text(
                result.message!,
                style: TextStyle(
                  fontSize: 11,
                  color: result.status == ToolTestStatus.fail
                      ? Colors.red.withValues(alpha: 0.7)
                      : Colors.green.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolStatusIcon extends StatelessWidget {
  final ToolTestStatus status;
  final double size;

  const _ToolStatusIcon({required this.status, required this.size});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ToolTestStatus.idle:
        return Icon(Icons.radio_button_unchecked,
            size: size, color: Colors.white.withValues(alpha: 0.2));
      case ToolTestStatus.running:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Colors.blue.withValues(alpha: 0.7)),
        );
      case ToolTestStatus.pass:
        return Icon(Icons.check_circle,
            size: size, color: Colors.green.withValues(alpha: 0.75));
      case ToolTestStatus.fail:
        return Icon(Icons.cancel,
            size: size, color: Colors.red.withValues(alpha: 0.75));
    }
  }
}
