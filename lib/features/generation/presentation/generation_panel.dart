import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart' as web;

import '../../../core/models/proposal_template_model.dart';
import '../../../core/repositories/proposal_templates_repository.dart';
import '../data/generation_history.dart';
import '../data/generation_notifier.dart';
import '../data/generation_state.dart';
import 'history_panel.dart';

String _scaffoldFor(ProposalTemplateModel t) =>
    t.promptScaffold ??
    'Gere o conteúdo usando o template "${t.name}":\n\nDescreva o que você precisa: [[detalhe aqui]]';

// Conta os marcadores [[...]] ainda não preenchidos
int _countPlaceholders(String text) =>
    RegExp(r'\[\[').allMatches(text).length;

class GenerationPanel extends ConsumerStatefulWidget {
  final String flowSlug;
  const GenerationPanel({super.key, required this.flowSlug});

  @override
  ConsumerState<GenerationPanel> createState() => _GenerationPanelState();
}

class _GenerationPanelState extends ConsumerState<GenerationPanel> {
  final _messageCtrl = TextEditingController();
  final _messageFocus = FocusNode();
  ProposalTemplateModel? _selectedTemplate;
  bool _thinkingExpanded = false;
  int _pendingFields = 0;

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(_onMessageChanged);
  }

  void _onMessageChanged() {
    final count = _countPlaceholders(_messageCtrl.text);
    if (count != _pendingFields) setState(() => _pendingFields = count);
  }

  @override
  void dispose() {
    _messageCtrl.removeListener(_onMessageChanged);
    _messageCtrl.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  void _selectTemplate(ProposalTemplateModel t) {
    final same = _selectedTemplate?.id == t.id;
    setState(() {
      if (same) {
        _selectedTemplate = null;
        _messageCtrl.clear();
      } else {
        _selectedTemplate = t;
        final scaffold = _scaffoldFor(t);
        _messageCtrl.text = scaffold;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _messageFocus.requestFocus();
          _jumpToNext();
        });
      }
    });
  }

  void _jumpToNext() {
    final text = _messageCtrl.text;
    final searchFrom = _messageCtrl.selection.isValid
        ? _messageCtrl.selection.end
        : 0;

    int start = text.indexOf('[[', searchFrom);
    if (start == -1) start = text.indexOf('[['); // wrap around
    if (start == -1) return;
    final end = text.indexOf(']]', start);
    if (end == -1) return;
    _messageCtrl.selection = TextSelection(
      baseOffset: start,
      extentOffset: end + 2,
    );
    _messageFocus.requestFocus();
  }

  void _submit() {
    final msg = _messageCtrl.text.trim();
    if (msg.isEmpty) return;
    ref.read(generationProvider.notifier).generate(
          flowSlug: widget.flowSlug,
          userMessage: msg,
          extraContext: _selectedTemplate?.content,
        );
  }

  void _reset() {
    ref.read(generationProvider.notifier).clear();
    setState(() {
      _thinkingExpanded = false;
      _selectedTemplate = null;
      _messageCtrl.clear();
    });
  }

  void _downloadHtml(String markdownText) {
    final body = md.markdownToHtml(
      markdownText,
      extensionSet: md.ExtensionSet.gitHubWeb,
    );
    final fullHtml = '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Metrifica — Output</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 800px; margin: 48px auto; padding: 0 24px; color: #1a1a1a; line-height: 1.7; }
  h1, h2, h3 { font-weight: 700; margin-top: 2em; }
  h1 { font-size: 2em; } h2 { font-size: 1.4em; } h3 { font-size: 1.1em; }
  table { border-collapse: collapse; width: 100%; margin: 1.5em 0; }
  th, td { border: 1px solid #e0e0e0; padding: 8px 12px; text-align: left; }
  th { background: #f5f5f5; font-weight: 600; }
  code { background: #f3f3f3; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
  pre { background: #f3f3f3; padding: 16px; border-radius: 8px; overflow-x: auto; }
  blockquote { border-left: 3px solid #ccc; margin: 0; padding-left: 16px; color: #555; }
</style>
</head>
<body>$body</body>
</html>''';

    final blob = web.Blob(
      [fullHtml.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.download = 'metrifica-output.html';
    a.click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(generationProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (state.status == GenerationStatus.thinking && state.hasThinking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_thinkingExpanded) setState(() => _thinkingExpanded = true);
      });
    }
    if (state.status == GenerationStatus.streaming && _thinkingExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _thinkingExpanded = false);
      });
    }
    // Salva no histórico assim que termina
    if (state.status == GenerationStatus.done && state.hasOutput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(historyProvider.notifier);
        // Salva só uma vez verificando se já existe pelo output
        final history = ref.read(historyProvider).valueOrNull ?? [];
        final alreadySaved = history.isNotEmpty &&
            history.first.output == state.output &&
            DateTime.now().difference(history.first.createdAt).inSeconds < 10;
        if (!alreadySaved) {
          notifier.add(
            flowSlug: widget.flowSlug,
            flowName: state.flowName,
            userMessage: _messageCtrl.text.trim(),
            templateName: _selectedTemplate?.name,
            output: state.output,
          );
        }
      });
    }

    final isInput = !state.isGenerating && state.status != GenerationStatus.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
        const SizedBox(height: 24),

        // ── Cabeçalho ─────────────────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome, size: 16, color: primary),
            ),
            const SizedBox(width: 10),
            Text('Gerar com IA',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
            const Spacer(),
            // Botão histórico
            Consumer(builder: (_, ref, __) {
              final count = ref.watch(historyProvider).valueOrNull?.length ?? 0;
              return TextButton.icon(
                onPressed: () => showHistoryPanel(context),
                icon: const Icon(Icons.history, size: 14),
                label: Text(
                  count > 0 ? 'Histórico ($count)' : 'Histórico',
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              );
            }),
            if (state.status != GenerationStatus.idle) ...[
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Novo', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ],
        ),

        if (isInput) ...[
          const SizedBox(height: 20),

          // ── Bloco 1: Template ─────────────────────────────────────────────
          _TemplateSelector(
            flowSlug: widget.flowSlug,
            selectedTemplate: _selectedTemplate,
            onSelect: _selectTemplate,
          ),

          const SizedBox(height: 20),

          // ── Bloco 2: Mensagem ─────────────────────────────────────────────
          _SectionLabel(
            icon: Icons.edit_outlined,
            label: 'Mensagem',
            caption: _selectedTemplate == null
                ? 'O que você quer gerar'
                : 'Substitua os campos [[marcados]] com os dados reais',
          ),
          const SizedBox(height: 8),

          // Banner de campos pendentes
          if (_pendingFields > 0) ...[
            _PlaceholderBanner(
              count: _pendingFields,
              onJump: _jumpToNext,
            ),
            const SizedBox(height: 8),
          ],

          TextField(
            controller: _messageCtrl,
            focusNode: _messageFocus,
            minLines: _selectedTemplate != null ? 8 : 3,
            maxLines: 16,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              fontFamily: _selectedTemplate != null ? 'monospace' : null,
            ),
            decoration: _inputDecoration(
              context,
              hint: 'Ex: Gere uma proposta para a Empresa X que precisa de...',
            ),
          ),

          const SizedBox(height: 16),

          // Botão gerar
          Row(
            children: [
              if (_pendingFields > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    '$_pendingFields campo${_pendingFields > 1 ? 's' : ''} para preencher',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Gerar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor:
                      _pendingFields > 0 ? primary.withValues(alpha: 0.5) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Estados de geração ────────────────────────────────────────────
        if (state.status == GenerationStatus.connecting)
          const _StatusRow(icon: Icons.cloud_outlined, label: 'Conectando ao modelo...'),

        if (state.hasThinking) ...[
          const SizedBox(height: 12),
          _ThinkingSection(
            text: state.thinking,
            isActive: state.status == GenerationStatus.thinking,
            expanded: _thinkingExpanded,
            onToggle: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
          ),
          const SizedBox(height: 16),
        ],

        if (state.hasOutput) ...[
          if (state.status == GenerationStatus.streaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StatusRow(
                  icon: Icons.edit_outlined, label: 'Gerando resposta...', pulse: true),
            ),
          _OutputCard(
            text: state.output,
            isDone: state.status == GenerationStatus.done,
            onDownloadHtml: () => _downloadHtml(state.output),
          ),
        ],

        if (state.status == GenerationStatus.error && state.error != null)
          _ErrorCard(message: state.error!),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Widgets auxiliares ────────────────────────────────────────────────────────

InputDecoration _inputDecoration(BuildContext context, {required String hint}) {
  final primary = Theme.of(context).colorScheme.primary;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.22),
        fontSize: 14,
        fontFamily: 'sans-serif'),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.04),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: primary.withValues(alpha: 0.45)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _PlaceholderBanner extends StatelessWidget {
  final int count;
  final VoidCallback onJump;

  const _PlaceholderBanner({required this.count, required this.onJump});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_outlined,
              size: 14, color: Colors.orange.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count campo${count > 1 ? 's' : ''} para preencher — substitua os textos entre [[ ]]',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onJump,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Próximo campo →',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String caption;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.7),
            )),
        const SizedBox(width: 8),
        Flexible(
          child: Text(caption,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _TemplateSelector extends ConsumerStatefulWidget {
  final String flowSlug;
  final ProposalTemplateModel? selectedTemplate;
  final void Function(ProposalTemplateModel) onSelect;

  const _TemplateSelector({
    required this.flowSlug,
    required this.selectedTemplate,
    required this.onSelect,
  });

  @override
  ConsumerState<_TemplateSelector> createState() => _TemplateSelectorState();
}

class _TemplateSelectorState extends ConsumerState<_TemplateSelector> {
  String? _previewSlug;

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(proposalTemplatesProvider(widget.flowSlug));

    return templatesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (templates) {
        if (templates.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              icon: Icons.description_outlined,
              label: 'Estrutura de referência',
              caption: 'opcional — preenche o campo de mensagem com um scaffold editável',
            ),
            const SizedBox(height: 10),
            ...templates.map((t) => _TemplateRadioCard(
                  template: t,
                  isSelected: widget.selectedTemplate?.id == t.id,
                  isPreviewOpen: _previewSlug == t.slug,
                  onTap: () => widget.onSelect(t),
                  onTogglePreview: () => setState(() =>
                      _previewSlug = _previewSlug == t.slug ? null : t.slug),
                )),
          ],
        );
      },
    );
  }
}

class _TemplateRadioCard extends StatelessWidget {
  final ProposalTemplateModel template;
  final bool isSelected;
  final bool isPreviewOpen;
  final VoidCallback onTap;
  final VoidCallback onTogglePreview;

  const _TemplateRadioCard({
    required this.template,
    required this.isSelected,
    required this.isPreviewOpen,
    required this.onTap,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: isPreviewOpen
                  ? const BorderRadius.vertical(top: Radius.circular(10))
                  : BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? primary
                              : Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        color: isSelected ? primary : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                          if (isSelected)
                            Text(
                              'Scaffold carregado no campo de mensagem',
                              style: TextStyle(
                                fontSize: 11,
                                color: primary.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (template.content != null)
                      GestureDetector(
                        onTap: onTogglePreview,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            isPreviewOpen ? 'fechar' : 'ver estrutura',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (isPreviewOpen && template.content != null)
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Text(
                    template.content!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.35),
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Geração: estados visuais ──────────────────────────────────────────────────

class _StatusRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool pulse;
  const _StatusRow({required this.icon, required this.label, this.pulse = false});

  @override
  State<_StatusRow> createState() => _StatusRowState();
}

class _StatusRowState extends State<_StatusRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return FadeTransition(
      opacity: widget.pulse ? _anim : const AlwaysStoppedAnimation(1.0),
      child: Row(
        children: [
          Icon(widget.icon, size: 14, color: primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(widget.label,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45))),
        ],
      ),
    );
  }
}

class _ThinkingSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (isActive)
                    _PulsingDot(color: primary)
                  else
                    Icon(Icons.lightbulb_outline,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Raciocínio em andamento...' : 'Raciocínio',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.3),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

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
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        decoration:
            BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String text;
  final bool isDone;
  final VoidCallback? onDownloadHtml;

  const _OutputCard({
    required this.text,
    required this.isDone,
    this.onDownloadHtml,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 0),
            child: Row(
              children: [
                if (isDone) ...[
                  Icon(Icons.check_circle_outline,
                      size: 13, color: Colors.green.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text('Concluído',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35))),
                ] else ...[
                  _PulsingDot(color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Gerando...',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35))),
                ],
                const Spacer(),
                if (isDone) ...[
                  IconButton(
                    onPressed: onDownloadHtml,
                    icon: const Icon(Icons.download_outlined, size: 15),
                    tooltip: 'Baixar como HTML',
                    color: Colors.white.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Copiado para a área de transferência'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    tooltip: 'Copiar markdown',
                    color: Colors.white.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownBody(
              data: text,
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.7, color: Colors.white.withValues(alpha: 0.8)),
                h1: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                h2: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
                h3: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
                code: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  color: theme.colorScheme.secondary,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                blockquote: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.45)),
                tableHead: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
                tableBody: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
          Icon(Icons.error_outline,
              size: 16, color: Colors.red.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13, color: Colors.red.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
  }
}
