import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/agent_run_model.dart';
import '../../../core/models/squad_run_model.dart';
import '../data/squad_history.dart';
import '../data/squad_notifier.dart';

void showSquadHistoryPanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar histórico',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const _SquadHistorySheet(),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
  );
}

class _SquadHistorySheet extends ConsumerStatefulWidget {
  const _SquadHistorySheet();

  @override
  ConsumerState<_SquadHistorySheet> createState() =>
      _SquadHistorySheetState();
}

class _SquadHistorySheetState extends ConsumerState<_SquadHistorySheet> {
  SquadRunModel? _selected;

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(squadRunsHistoryProvider);
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: const Color(0xFF0F0F18),
        child: SizedBox(
          width: 560,
          height: double.infinity,
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  children: [
                    if (_selected != null)
                      IconButton(
                        onPressed: () => setState(() => _selected = null),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        color: Colors.white.withValues(alpha: 0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      Icon(Icons.history,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selected != null
                            ? (_selected!.squadName ?? 'Run')
                            : 'Histórico de Runs',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.white.withValues(alpha: 0.4),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Body ──────────────────────────────────────────────────
              Expanded(
                child: _selected != null
                    ? _RunDetail(
                        run: _selected!,
                        onDelete: () {
                          ref
                              .read(squadRunsHistoryProvider.notifier)
                              .remove(_selected!.id);
                          setState(() => _selected = null);
                        },
                      )
                    : runsAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 1.5)),
                        error: (e, _) =>
                            Center(child: Text('Erro: $e')),
                        data: (runs) => runs.isEmpty
                            ? _EmptyState()
                            : RefreshIndicator(
                                onRefresh: () => ref
                                    .read(squadRunsHistoryProvider.notifier)
                                    .refresh(),
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: runs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (_, i) => _RunTile(
                                    run: runs[i],
                                    onTap: () =>
                                        setState(() => _selected = runs[i]),
                                    onDelete: () => ref
                                        .read(squadRunsHistoryProvider.notifier)
                                        .remove(runs[i].id),
                                  ),
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_2_outlined,
              size: 40, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text(
            'Nenhum run ainda',
            style: TextStyle(
                fontSize: 14, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
}

// ─── Run tile (lista) ─────────────────────────────────────────────────────────

class _RunTile extends StatelessWidget {
  final SquadRunModel run;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RunTile({
    required this.run,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    final isDone = run.status == 'done';
    final isError = run.status == 'error';

    return Material(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isError
                                ? Colors.red.withValues(alpha: 0.12)
                                : isDone
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isError
                                ? 'erro'
                                : isDone
                                    ? 'concluído'
                                    : 'rodando',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: isError
                                  ? Colors.red.withValues(alpha: 0.8)
                                  : isDone
                                      ? Colors.green.withValues(alpha: 0.8)
                                      : Colors.orange.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (run.squadName != null)
                          Text(
                            run.squadName!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          run.createdAt != null
                              ? fmt.format(
                                  DateTime.parse(run.createdAt!).toLocal())
                              : '',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      run.initialPrompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(Icons.chevron_right,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Run detail (detalhe de um run com agent_runs) ────────────────────────────

class _RunDetail extends ConsumerStatefulWidget {
  final SquadRunModel run;
  final VoidCallback onDelete;

  const _RunDetail({required this.run, required this.onDelete});

  @override
  ConsumerState<_RunDetail> createState() => _RunDetailState();
}

class _RunDetailState extends ConsumerState<_RunDetail> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final agentRunsAsync =
        ref.watch(agentRunsForSquadProvider(widget.run.id));
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta
          Row(
            children: [
              Text(
                widget.run.createdAt != null
                    ? fmt.format(
                        DateTime.parse(widget.run.createdAt!).toLocal())
                    : '',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.3)),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF0F0F18),
                      title: const Text('Excluir este run?',
                          style: TextStyle(fontSize: 15)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancelar')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDelete();
                          },
                          child: Text('Excluir',
                              style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.8))),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 15),
                color: Colors.white.withValues(alpha: 0.25),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Prompt inicial
          Text(
            'PROMPT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.run.initialPrompt,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),

          const SizedBox(height: 20),

          // Agent runs
          Text(
            'AGENTES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 10),

          agentRunsAsync.when(
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )),
            error: (e, _) => Text('Erro: $e'),
            data: (agentRuns) => agentRuns.isEmpty
                ? Text(
                    'Nenhum agente executado',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.3)),
                  )
                : Column(
                    children: [
                      ...agentRuns
                          .map((ar) => _AgentRunCard(
                                agentRun: ar,
                                expanded: _expanded.contains(ar.id),
                                onToggle: () => setState(() {
                                  if (_expanded.contains(ar.id)) {
                                    _expanded.remove(ar.id);
                                  } else {
                                    _expanded.add(ar.id);
                                  }
                                }),
                              )),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            ref.read(squadProvider.notifier).restore(
                                  run: widget.run,
                                  agentRuns: agentRuns,
                                );
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.restore, size: 16),
                          label: const Text('Restaurar na view principal'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Agent run card ───────────────────────────────────────────────────────────

class _AgentRunCard extends StatelessWidget {
  final AgentRunModel agentRun;
  final bool expanded;
  final VoidCallback onToggle;

  const _AgentRunCard({
    required this.agentRun,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = agentRun.status == 'done';
    final hasOutput =
        agentRun.output != null && agentRun.output!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: hasOutput ? onToggle : null,
              borderRadius: expanded
                  ? const BorderRadius.vertical(top: Radius.circular(10))
                  : BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Row(
                  children: [
                    // Step badge
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isDone
                            ? Icon(Icons.check,
                                size: 12,
                                color: Colors.green.withValues(alpha: 0.8))
                            : Text(
                                '${agentRun.stepIndex + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      Colors.white.withValues(alpha: 0.4),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        agentRun.agentName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    if (hasOutput) ...[
                      if (agentRun.output != null)
                        Text(
                          '${agentRun.output!.length} chars',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ] else
                      Text(
                        agentRun.status,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Output expandido
            if (expanded && hasOutput) ...[
              Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Copy button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(
                                text: agentRun.output!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copiado'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_outlined, size: 14),
                          tooltip: 'Copiar',
                          color: Colors.white.withValues(alpha: 0.3),
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    MarkdownBody(
                      data: agentRun.output!,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.7,
                            color: Colors.white.withValues(alpha: 0.75)),
                        h1: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        h2: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        h3: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        code: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.06),
                          color: theme.colorScheme.secondary,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
