import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/organization_provider.dart';
import '../data/squad_notifier.dart';
import '../data/squad_state.dart';

class SquadRunPanel extends ConsumerStatefulWidget {
  final String squadSlug;
  const SquadRunPanel({super.key, required this.squadSlug});

  @override
  ConsumerState<SquadRunPanel> createState() => _SquadRunPanelState();
}

class _SquadRunPanelState extends ConsumerState<SquadRunPanel> {
  final _msgCtrl = TextEditingController();
  final Set<String> _expandedThinking = {};
  final Set<String> _expandedOutput = {};

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) return;
    final orgId = ref.read(activeOrgProvider)?.id;
    ref.read(squadProvider.notifier).run(
          squadSlug: widget.squadSlug,
          userMessage: msg,
          organizationId: orgId,
        );
  }

  void _reset() {
    ref.read(squadProvider.notifier).clear();
    setState(() {
      _expandedThinking.clear();
      _expandedOutput.clear();
      _msgCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(squadProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input block
          if (!state.isRunning && !state.hasAgents)
            _InputBlock(controller: _msgCtrl, onSubmit: _submit),

          // Connecting spinner
          if (state.status == SquadStatus.connecting)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Inicializando squad...',
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

          // Agent runs
          if (state.hasAgents) ...[
            // Orchestrator thinking badge
            if (state.orchestratorThinking != null &&
                state.orchestratorThinking!.isNotEmpty)
              _OrchestratorBadge(text: state.orchestratorThinking!),

            const SizedBox(height: 16),

            // Agent timeline
            ...state.agentRuns.map((agent) {
              final thinkingKey = '${agent.agentSlug}_${agent.step}';
              final outputKey = '${agent.agentSlug}_${agent.step}_out';

              return _AgentCard(
                agent: agent,
                // Auto-expand thinking while agent is running so user sees live reasoning
                thinkingExpanded:
                    agent.isActive || _expandedThinking.contains(thinkingKey),
                outputExpanded:
                    agent.isActive || _expandedOutput.contains(outputKey),
                onToggleThinking: () => setState(() {
                  if (_expandedThinking.contains(thinkingKey)) {
                    _expandedThinking.remove(thinkingKey);
                  } else {
                    _expandedThinking.add(thinkingKey);
                  }
                }),
                onToggleOutput: () => setState(() {
                  if (_expandedOutput.contains(outputKey)) {
                    _expandedOutput.remove(outputKey);
                  } else {
                    _expandedOutput.add(outputKey);
                  }
                }),
              );
            }),
          ],

          // Error
          if (state.status == SquadStatus.error && state.error != null) ...[
            const SizedBox(height: 16),
            _ErrorCard(message: state.error!),
          ],

          // Done / reset / resume
          if (state.isDone || state.status == SquadStatus.error) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                if (state.runId != null &&
                    state.initialPrompt != null &&
                    state.hasAgents)
                  FilledButton.icon(
                    onPressed: () => ref.read(squadProvider.notifier).resume(
                          squadSlug: widget.squadSlug,
                          userMessage: state.initialPrompt!,
                          runId: state.runId!,
                        ),
                    icon: const Icon(Icons.fast_forward_rounded, size: 15),
                    label: const Text('Continuar execução'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (state.runId != null && state.hasAgents)
                  const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Nova execução'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.75),
                    side: BorderSide(color: outline.withValues(alpha: 0.8)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Input block ──────────────────────────────────────────────────────────────

class _InputBlock extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _InputBlock({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      controller.text = 'landing page de bolo de fubá apple like moderna';
    }

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descreva o que a squad deve desenvolver',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.04),
            border: Border.all(color: outline.withValues(alpha: 0.65)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              TextField(
                controller: controller,
                maxLines: 6,
                minLines: 4,
                style: const TextStyle(fontSize: 13, height: 1.6),
                decoration: InputDecoration(
                  hintText:
                      'Ex: Criar um sistema de autenticação com JWT, incluindo login, registro e refresh token...',
                  hintStyle: TextStyle(
                    color: onSurface.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: onSubmit,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Executar Squad'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Orchestrator thinking badge ──────────────────────────────────────────────

class _OrchestratorBadge extends StatelessWidget {
  final String text;
  const _OrchestratorBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outline = Theme.of(context).colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.03),
        border: Border.all(color: outline.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hub_outlined,
            size: 13,
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: onSurface.withValues(alpha: 0.55),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Agent card ───────────────────────────────────────────────────────────────

class _AgentCard extends StatelessWidget {
  final AgentRunState agent;
  final bool thinkingExpanded;
  final bool outputExpanded;
  final VoidCallback onToggleThinking;
  final VoidCallback onToggleOutput;

  const _AgentCard({
    required this.agent,
    required this.thinkingExpanded,
    required this.outputExpanded,
    required this.onToggleThinking,
    required this.onToggleOutput,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.02),
          border: Border.all(
            color: agent.isActive
                ? primary.withValues(alpha: 0.3)
                : outline.withValues(alpha: 0.55),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent header
            InkWell(
              onTap: agent.isDone ? onToggleOutput : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    // Status indicator
                    if (agent.isActive)
                      _PulsingDot(color: primary)
                    else if (agent.isDone)
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.green.withValues(alpha: 0.7),
                      )
                    else
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: onSurface.withValues(alpha: 0.25),
                        ),
                      ),
                    const SizedBox(width: 10),
                    // Agent name + step
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            agent.agentName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: agent.isActive
                                  ? onSurface.withValues(alpha: 0.92)
                                  : agent.isDone
                                      ? onSurface.withValues(alpha: 0.75)
                                      : onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: onSurface.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'passo ${agent.step + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (agent.isDone)
                      Icon(
                        outputExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: onSurface.withValues(alpha: 0.45),
                      ),
                    if (agent.isActive)
                      Text(
                        agent.hasThinking
                            ? 'pensando… ${agent.thinking.length} chars'
                            : 'executando…',
                        style: TextStyle(
                          fontSize: 11,
                          color: primary.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Tool calls
            if (agent.hasToolCalls && (agent.isActive || outputExpanded)) ...[
              Divider(height: 1, color: outline.withValues(alpha: 0.5)),
              _ToolCallsSection(toolCalls: agent.toolCalls),
            ],

            // Thinking section (active or expanded)
            if (agent.hasThinking && (agent.isActive || outputExpanded)) ...[
              Divider(height: 1, color: outline.withValues(alpha: 0.5)),
              _ThinkingSection(
                text: agent.thinking,
                isActive: agent.isActive,
                expanded: thinkingExpanded,
                onToggle: onToggleThinking,
              ),
            ],

            // Output section
            if (agent.hasOutput && (agent.isActive || outputExpanded)) ...[
              Divider(height: 1, color: outline.withValues(alpha: 0.5)),
              _OutputSection(
                text: agent.output,
                isDone: agent.isDone,
                agentName: agent.agentName,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Tool calls section ───────────────────────────────────────────────────────

class _ToolCallsSection extends StatelessWidget {
  final List<ToolCallState> toolCalls;
  const _ToolCallsSection({required this.toolCalls});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: toolCalls.map((tc) => _ToolCallRow(tc: tc)).toList(),
      ),
    );
  }
}

class _ToolCallRow extends StatelessWidget {
  final ToolCallState tc;
  const _ToolCallRow({required this.tc});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 8),
            child: tc.isPending
                ? _PulsingDot(color: primary)
                : Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.green.withValues(alpha: 0.7),
                  ),
          ),
          // Tool name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tc.tool,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: primary.withValues(alpha: 0.8),
              ),
            ),
          ),
          if (tc.result != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tc.result!.length > 120
                    ? '${tc.result!.substring(0, 120)}…'
                    : tc.result!,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                  height: 1.4,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 8),
            Text(
              'executando...',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Thinking section ─────────────────────────────────────────────────────────

class _ThinkingSection extends StatefulWidget {
  final String text;
  final bool isActive;
  final bool expanded;
  final VoidCallback onToggle;

  const _ThinkingSection({
    required this.text,
    required this.isActive,
    required this.expanded,
    required this.onToggle,
  });

  @override
  State<_ThinkingSection> createState() => _ThinkingSectionState();
}

class _ThinkingSectionState extends State<_ThinkingSection> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_ThinkingSection old) {
    super.didUpdateWidget(old);
    // Auto-scroll to bottom when new thinking arrives while active
    if (widget.isActive && widget.text != old.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Last non-empty line of thinking — shown in header as live preview
  String get _lastLine {
    if (widget.text.isEmpty) return '';
    final lines = widget.text.trimRight().split('\n');
    for (var i = lines.length - 1; i >= 0; i--) {
      final l = lines[i].trim();
      if (l.isNotEmpty) return l.length > 80 ? '${l.substring(0, 80)}…' : l;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final lastLine = _lastLine;

    return Column(
      children: [
        InkWell(
          onTap: widget.onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.isActive)
                  _PulsingDot(color: primary)
                else
                  Icon(
                    Icons.lightbulb_outline,
                    size: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isActive
                            ? 'Raciocínio em andamento…'
                            : 'Raciocínio (${widget.text.length} chars)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                      // Live last-line preview — shows even when collapsed
                      if (widget.isActive &&
                          lastLine.isNotEmpty &&
                          !widget.expanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            lastLine,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  widget.expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        if (widget.expanded)
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              controller: _scroll,
              child: Text(
                widget.text.isEmpty
                    ? 'Aguardando resposta do modelo…'
                    : widget.text,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.65,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Output section ───────────────────────────────────────────────────────────

class _OutputSection extends StatelessWidget {
  final String text;
  final bool isDone;
  final String agentName;

  const _OutputSection({
    required this.text,
    required this.isDone,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 0),
          child: Row(
            children: [
              if (isDone) ...[
                Icon(
                  Icons.check_circle_outline,
                  size: 12,
                  color: Colors.green.withValues(alpha: 0.65),
                ),
                const SizedBox(width: 6),
                Text(
                  'Concluído',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ] else ...[
                _PulsingDot(color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Gerando...',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              const Spacer(),
              if (isDone)
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copiado para a área de transferência'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined, size: 14),
                  tooltip: 'Copiar markdown',
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: MarkdownBody(
            data: text,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                height: 1.7,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
              h1: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              h2: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              h3: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                backgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.08),
                color: theme.colorScheme.secondary,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              blockquoteDecoration: BoxDecoration(
                color: const Color(0xFF111827),
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary.withValues(alpha: 0.65),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Error card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline,
            size: 15,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pulsing dot (shared with agent status) ───────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
