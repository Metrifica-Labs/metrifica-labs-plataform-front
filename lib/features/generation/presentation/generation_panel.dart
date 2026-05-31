import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart' as web;

import '../../../core/models/proposal_template_model.dart';
import '../../../core/providers/organization_provider.dart';
import '../../../core/repositories/proposal_templates_repository.dart';
import '../../editorial/data/posts_repository.dart';
import '../data/generation_history.dart';
import '../data/generation_notifier.dart';
import '../data/generation_state.dart';
import 'history_panel.dart';

String? _extractPillar(String text) {
  final match = RegExp(r'PILAR:\s*(\S+)', caseSensitive: false).firstMatch(text);
  return match?.group(1);
}

String _debugPrefill(String flowSlug) {
  switch (flowSlug) {
    case 'post-instagram':
      return '''Crie um post completo para Instagram.

PILAR: 1 - Dor do empresário sem tecnologia adequada

TEMA: O custo invisível de não ter tecnologia própria na operação

HOOK (slide 1): "Quanto está custando não ter tecnologia própria na sua operação?"

NARRATIVA (6-8 slides):
- Dor: equipe gastando 80% do tempo em tarefas repetitivas, retrabalho constante, dados espalhados em planilhas
- Agravamento: cada mês sem sistema próprio é vantagem que o concorrente ganha — você perde velocidade, controle e dinheiro
- Virada: o problema não é a sua equipe. é a ausência de um sistema.
- Solução Metrifica: tecnologia sob medida para automatizar o essencial e preparar a operação para escalar

DADOS: 80% do tempo em tarefas repetitivas — apenas 20% no que realmente move o negócio

TEMPLATE DE IMAGEM: Template 6 — Infográfico com comparação 80% vs 20% para o slide de dados; escolha o template visual adequado para cada um dos demais slides

OBSERVAÇÕES: carrossel de 6-8 slides, slide de apresentação da Metrifica no penúltimo. IMPORTANTE: gere um prompt de imagem COMPLETO para CADA slide do carrossel, um por slide, cada prompt dentro do seu próprio bloco de código ``` ``` na ordem dos slides''';
    default:
      return '';
  }
}

String _scaffoldFor(ProposalTemplateModel t) =>
    t.promptScaffold ??
    'Gere o conteúdo usando o template "${t.name}":\n\nDescreva o que você precisa: [[detalhe aqui]]';

int _countPlaceholders(String text) => RegExp(r'\[\[').allMatches(text).length;

class GenerationPanel extends ConsumerStatefulWidget {
  final String flowSlug;
  final String? extraContext;
  const GenerationPanel({super.key, required this.flowSlug, this.extraContext});

  @override
  ConsumerState<GenerationPanel> createState() => _GenerationPanelState();
}

class _GenerationPanelState extends ConsumerState<GenerationPanel> {
  final _messageCtrl = TextEditingController();
  final _messageFocus = FocusNode();
  final _refinementCtrl = TextEditingController();
  final _refinementFocus = FocusNode();
  ProposalTemplateModel? _selectedTemplate;
  bool _thinkingExpanded = false;
  int _pendingFields = 0;
  String? _postSavedOutput;
  String? _savedPostId;
  bool _imagePatched = false;

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(_onMessageChanged);
    _messageFocus.onKeyEvent = (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.tab &&
          _pendingFields > 0) {
        _jumpToNext();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    if (kDebugMode) {
      _messageCtrl.text = _debugPrefill(widget.flowSlug);
    }
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
    _refinementCtrl.dispose();
    _refinementFocus.dispose();
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
    final searchFrom =
        _messageCtrl.selection.isValid ? _messageCtrl.selection.end : 0;

    int start = text.indexOf('[[', searchFrom);
    if (start == -1) start = text.indexOf('[[');
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
    final parts = [
      if (widget.extraContext != null && widget.extraContext!.isNotEmpty)
        widget.extraContext!,
      if (_selectedTemplate?.content != null) _selectedTemplate!.content!,
    ];
    ref.read(generationProvider.notifier).generate(
          flowSlug: widget.flowSlug,
          userMessage: msg,
          extraContext: parts.isEmpty ? null : parts.join('\n\n---\n\n'),
        );
  }

  void _reset() {
    ref.read(generationProvider.notifier).clear();
    setState(() {
      _thinkingExpanded = false;
      _selectedTemplate = null;
      _messageCtrl.clear();
      _refinementCtrl.clear();
      _postSavedOutput = null;
      _savedPostId = null;
      _imagePatched = false;
    });
  }

  void _submitRefinement() {
    final msg = _refinementCtrl.text.trim();
    if (msg.isEmpty) return;
    _refinementCtrl.clear();
    ref.read(generationProvider.notifier).refine(
          flowSlug: widget.flowSlug,
          correction: msg,
        );
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
    final onSurface = theme.colorScheme.onSurface;

    if (state.status == GenerationStatus.thinking && state.hasThinking) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_thinkingExpanded) {
          setState(() => _thinkingExpanded = true);
        }
      });
    }
    if (state.status == GenerationStatus.streaming && _thinkingExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _thinkingExpanded = false);
      });
    }
    if (state.status == GenerationStatus.done && state.hasOutput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(historyProvider.notifier);
        final history = ref.read(historyProvider).valueOrNull ?? [];
        final alreadySaved =
            history.isNotEmpty &&
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
        if (_postSavedOutput != state.output) {
          _postSavedOutput = state.output;
          final orgId = ref.read(activeOrgProvider)?.id;
          if (orgId != null) {
            ref
                .read(postsRepositoryProvider)
                .createDraft(
                  orgId: orgId,
                  flowSlug: widget.flowSlug,
                  content: state.output,
                  pillar: _extractPillar(state.output),
                )
                .then((post) {
              if (mounted) {
                _savedPostId = post.id;
                ref.invalidate(postsProvider);
              }
            });
          }
        }
      });
    }
    if (state.imageStatus == ImageStatus.done &&
        state.imageUrl != null &&
        _savedPostId != null &&
        !_imagePatched) {
      _imagePatched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(postsRepositoryProvider)
            .updateImageUrl(_savedPostId!, state.imageUrl!);
      });
    }

    final isInput =
        !state.isGenerating && state.status != GenerationStatus.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: onSurface.withValues(alpha: 0.08), height: 1),
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
            Text(
              'Gerar com IA',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),
            Consumer(
              builder: (_, ref, __) {
                final count =
                    ref.watch(historyProvider).valueOrNull?.length ?? 0;
                return TextButton.icon(
                  onPressed: () => showHistoryPanel(context),
                  icon: const Icon(Icons.history, size: 14),
                  label: Text(
                    count > 0 ? 'Histórico ($count)' : 'Histórico',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                );
              },
            ),
            if (state.status != GenerationStatus.idle) ...[
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Novo', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: onSurface.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ],
        ),

        if (isInput) ...[
          const SizedBox(height: 20),
          _TemplateSelector(
            flowSlug: widget.flowSlug,
            selectedTemplate: _selectedTemplate,
            onSelect: _selectTemplate,
          ),
          const SizedBox(height: 20),
          _SectionLabel(
            icon: Icons.edit_outlined,
            label: 'Mensagem',
            caption: _selectedTemplate == null
                ? 'O que você quer gerar'
                : 'Substitua os campos [[marcados]] com os dados reais',
          ),
          const SizedBox(height: 8),
          if (_pendingFields > 0) ...[
            _PlaceholderBanner(count: _pendingFields, onJump: _jumpToNext),
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
                label: const Text(
                  'Gerar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  backgroundColor: _pendingFields > 0
                      ? primary.withValues(alpha: 0.5)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        if (state.status == GenerationStatus.connecting)
          const _StatusRow(
            icon: Icons.cloud_outlined,
            label: 'Conectando ao modelo...',
          ),

        if (state.turns.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChatHistory(turns: state.turns),
          const SizedBox(height: 16),
        ],

        if (state.hasThinking) ...[
          const SizedBox(height: 12),
          _ThinkingSection(
            text: state.thinking,
            isActive: state.status == GenerationStatus.thinking,
            expanded: _thinkingExpanded,
            onToggle:
                () => setState(() => _thinkingExpanded = !_thinkingExpanded),
          ),
          const SizedBox(height: 16),
        ],

        if (state.hasOutput) ...[
          if (state.status == GenerationStatus.streaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StatusRow(
                icon: Icons.edit_outlined,
                label: state.isRefinement
                    ? 'Aplicando ajuste...'
                    : 'Gerando resposta...',
                pulse: true,
              ),
            ),
          _OutputCard(
            text: state.output,
            isDone: state.status == GenerationStatus.done,
            onDownloadHtml: () => _downloadHtml(state.output),
          ),
        ],

        if (state.status == GenerationStatus.done && state.hasImagePrompt) ...[
          const SizedBox(height: 16),
          _ImageGenerationSection(
            imagePrompts: state.extractedImagePrompts,
            imageStatus: state.imageStatus,
            imageUrl: state.imageUrl,
            imageError: state.imageError,
            onGenerate: (prompt, ratio) => ref
                .read(generationProvider.notifier)
                .generateImage(prompt: prompt, aspectRatio: ratio),
            onClear: () => ref.read(generationProvider.notifier).clearImage(),
          ),
        ],

        if (state.status == GenerationStatus.done) ...[
          const SizedBox(height: 20),
          _RefinementInput(
            controller: _refinementCtrl,
            focusNode: _refinementFocus,
            onSubmit: _submitRefinement,
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
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  final onSurface = theme.colorScheme.onSurface;
  final outline = theme.colorScheme.outline;

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: onSurface.withValues(alpha: 0.3),
      fontSize: 14,
      fontFamily: 'sans-serif',
    ),
    filled: true,
    fillColor: onSurface.withValues(alpha: 0.03),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: outline),
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
          Icon(
            Icons.edit_note_outlined,
            size: 14,
            color: Colors.orange.withValues(alpha: 0.8),
          ),
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
                'Próximo campo → (Tab)',
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Icon(icon, size: 13, color: onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              color: onSurface.withValues(alpha: 0.35),
            ),
            overflow: TextOverflow.ellipsis,
          ),
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
    final templatesAsync = ref.watch(
      proposalTemplatesProvider(widget.flowSlug),
    );

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
              caption:
                  'opcional — preenche o campo de mensagem com um scaffold editável',
            ),
            const SizedBox(height: 10),
            ...templates.map(
              (t) => _TemplateRadioCard(
                template: t,
                isSelected: widget.selectedTemplate?.id == t.id,
                isPreviewOpen: _previewSlug == t.slug,
                onTap: () => widget.onSelect(t),
                onTogglePreview: () => setState(
                  () => _previewSlug = _previewSlug == t.slug ? null : t.slug,
                ),
              ),
            ),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.07)
              : onSurface.withValues(alpha: 0.03),
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.35)
                : outline.withValues(alpha: 0.5),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                              : onSurface.withValues(alpha: 0.25),
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
                                  ? onSurface.withValues(alpha: 0.9)
                                  : onSurface.withValues(alpha: 0.6),
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
                              color: onSurface.withValues(alpha: 0.35),
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
                    top: BorderSide(color: outline.withValues(alpha: 0.4)),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Text(
                    template.content!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: onSurface.withValues(alpha: 0.4),
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
  const _StatusRow({
    required this.icon,
    required this.label,
    this.pulse = false,
  });

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
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return FadeTransition(
      opacity: widget.pulse ? _anim : const AlwaysStoppedAnimation(1.0),
      child: Row(
        children: [
          Icon(widget.icon, size: 14, color: primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              color: onSurface.withValues(alpha: 0.45),
            ),
          ),
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.02),
        border: Border.all(color: outline.withValues(alpha: 0.4)),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (isActive)
                    _PulsingDot(color: primary)
                  else
                    Icon(
                      Icons.lightbulb_outline,
                      size: 14,
                      color: onSurface.withValues(alpha: 0.3),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Raciocínio em andamento...' : 'Raciocínio',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 14,
                    color: onSurface.withValues(alpha: 0.25),
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
                    color: onSurface.withValues(alpha: 0.35),
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
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
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
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
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
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.02),
        border: Border.all(color: outline.withValues(alpha: 0.5)),
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
                  Icon(
                    Icons.check_circle_outline,
                    size: 13,
                    color: Colors.green.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Concluído',
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ] else ...[
                  _PulsingDot(color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Gerando...',
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
                const Spacer(),
                if (isDone) ...[
                  IconButton(
                    onPressed: onDownloadHtml,
                    icon: const Icon(Icons.download_outlined, size: 15),
                    tooltip: 'Baixar como HTML',
                    color: onSurface.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 2),
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
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    tooltip: 'Copiar markdown',
                    color: onSurface.withValues(alpha: 0.4),
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
              styleSheet: _markdownOutputStyle(theme),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Geração de Imagem ────────────────────────────────────────────────────────

class _ImageGenerationSection extends StatefulWidget {
  final List<String> imagePrompts;
  final ImageStatus imageStatus;
  final String? imageUrl;
  final String? imageError;
  final void Function(String prompt, String aspectRatio) onGenerate;
  final VoidCallback onClear;

  const _ImageGenerationSection({
    required this.imagePrompts,
    required this.imageStatus,
    required this.imageUrl,
    required this.imageError,
    required this.onGenerate,
    required this.onClear,
  });

  @override
  State<_ImageGenerationSection> createState() =>
      _ImageGenerationSectionState();
}

class _ImageGenerationSectionState extends State<_ImageGenerationSection> {
  late final TextEditingController _promptCtrl;
  String _aspectRatio = '4:5';
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _promptCtrl = TextEditingController(
      text: widget.imagePrompts.isNotEmpty ? widget.imagePrompts.first : '',
    );
  }

  void _selectSlide(int index) {
    setState(() {
      _selectedIndex = index;
      _promptCtrl.text = widget.imagePrompts[index];
    });
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.02),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image_outlined, size: 16, color: primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Gerar Imagem',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (widget.imageStatus == ImageStatus.done)
                TextButton.icon(
                  onPressed: widget.onClear,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Nova', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.imagePrompts.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.imagePrompts.length, (i) {
                  final selected = i == _selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _selectSlide(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? primary.withValues(alpha: 0.15)
                              : onSurface.withValues(alpha: 0.04),
                          border: Border.all(
                            color: selected
                                ? primary.withValues(alpha: 0.5)
                                : outline.withValues(alpha: 0.5),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Slide ${i + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? primary
                                : onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (widget.imageStatus == ImageStatus.done &&
              widget.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.imageUrl!,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 200,
                        color: onSurface.withValues(alpha: 0.04),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: onSurface.withValues(alpha: 0.04),
                  child: Center(
                    child: Text(
                      'Erro ao carregar imagem',
                      style: TextStyle(color: onSurface.withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final a =
                    web.document.createElement('a') as web.HTMLAnchorElement;
                a.href = widget.imageUrl!;
                a.download = 'metrifica-image.jpg';
                a.target = '_blank';
                a.click();
              },
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Baixar imagem', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurface.withValues(alpha: 0.5),
                side: BorderSide(color: outline.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ] else if (widget.imageStatus == ImageStatus.generating) ...[
            _ImageGeneratingIndicator(),
          ] else if (widget.imageStatus == ImageStatus.error) ...[
            _ErrorCard(message: widget.imageError ?? 'Erro desconhecido'),
            const SizedBox(height: 12),
            _ImageForm(
              promptCtrl: _promptCtrl,
              aspectRatio: _aspectRatio,
              onAspectRatioChanged: (v) => setState(() => _aspectRatio = v),
              onGenerate: () =>
                  widget.onGenerate(_promptCtrl.text.trim(), _aspectRatio),
            ),
          ] else ...[
            _ImageForm(
              promptCtrl: _promptCtrl,
              aspectRatio: _aspectRatio,
              onAspectRatioChanged: (v) => setState(() => _aspectRatio = v),
              onGenerate: () =>
                  widget.onGenerate(_promptCtrl.text.trim(), _aspectRatio),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageForm extends StatelessWidget {
  final TextEditingController promptCtrl;
  final String aspectRatio;
  final ValueChanged<String> onAspectRatioChanged;
  final VoidCallback onGenerate;

  const _ImageForm({
    required this.promptCtrl,
    required this.aspectRatio,
    required this.onAspectRatioChanged,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    const ratios = ['1:1', '4:5', '9:16', '16:9'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: promptCtrl,
          minLines: 4,
          maxLines: 8,
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            fontFamily: 'monospace',
          ),
          decoration: _inputDecoration(
            context,
            hint: 'Prompt de imagem gerado pelo modelo...',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Proporção:',
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: 10),
            ...ratios.map((r) {
              final selected = r == aspectRatio;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onAspectRatioChanged(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? primary.withValues(alpha: 0.15)
                          : onSurface.withValues(alpha: 0.04),
                      border: Border.all(
                        color: selected
                            ? primary.withValues(alpha: 0.5)
                            : outline.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? primary
                            : onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_awesome, size: 14),
              label: const Text(
                'Gerar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageGeneratingIndicator extends StatefulWidget {
  @override
  State<_ImageGeneratingIndicator> createState() =>
      _ImageGeneratingIndicatorState();
}

class _ImageGeneratingIndicatorState extends State<_ImageGeneratingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0)
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
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return FadeTransition(
      opacity: _anim,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gerando imagem com Higgsfield Soul...',
              style: TextStyle(
                fontSize: 12,
                color: onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat history (previous turns) ────────────────────────────────────────────

class _ChatHistory extends StatefulWidget {
  final List<ChatTurn> turns;
  const _ChatHistory({required this.turns});

  @override
  State<_ChatHistory> createState() => _ChatHistoryState();
}

class _ChatHistoryState extends State<_ChatHistory> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.turns.asMap().entries.map((e) {
        final i = e.key;
        final turn = e.value;
        final isOpen = _expanded.contains(i);
        final label = turn.userMessage.length > 80
            ? '${turn.userMessage.substring(0, 80)}...'
            : turn.userMessage;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.02),
              border: Border.all(color: outline.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => setState(() {
                    if (isOpen) {
                      _expanded.remove(i);
                    } else {
                      _expanded.add(i);
                    }
                  }),
                  borderRadius: isOpen
                      ? const BorderRadius.vertical(top: Radius.circular(10))
                      : BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 13,
                            color: onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurface.withValues(alpha: 0.5),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          isOpen
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 14,
                          color: onSurface.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: outline.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(14),
                      child: MarkdownBody(
                        data: turn.output,
                        styleSheet: _markdownOutputStyle(theme).copyWith(
                          p: theme.textTheme.bodySmall?.copyWith(
                            height: 1.6,
                            color: onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Refinement input ─────────────────────────────────────────────────────────

class _RefinementInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  const _RefinementInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.02),
        border: Border.all(color: outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 13, color: onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 6),
              Text(
                'Pedir ajuste ou correção',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText:
                        'Ex: Torne o tom mais formal, remova a parte sobre X...',
                    hintStyle: TextStyle(
                      color: onSurface.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: onSurface.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: primary.withValues(alpha: 0.45)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSubmit,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: Size.zero,
                ),
                child: const Icon(Icons.send_rounded, size: 15),
              ),
            ],
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
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline,
                  size: 16, color: Colors.red.withValues(alpha: 0.7)),
              const SizedBox(width: 8),
              Text(
                'Erro',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro copiado'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 14),
                tooltip: 'Copiar erro',
                color: Colors.red.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            message,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              fontFamily: 'monospace',
              color: Colors.red.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared markdown output style ─────────────────────────────────────────────

MarkdownStyleSheet _markdownOutputStyle(ThemeData theme) {
  final onSurface = theme.colorScheme.onSurface;
  final codeBlock = theme.colorScheme.surfaceContainerHighest;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(
      height: 1.7,
      color: onSurface.withValues(alpha: 0.8),
    ),
    h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    tableHead: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    tableBody: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.75)),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      fontStyle: FontStyle.italic,
      color: onSurface.withValues(alpha: 0.5),
    ),
    blockquoteDecoration: BoxDecoration(
      color: codeBlock,
      border: Border(
        left: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.65),
          width: 3,
        ),
      ),
    ),
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      backgroundColor: codeBlock,
      color: theme.colorScheme.secondary,
    ),
    codeblockDecoration: BoxDecoration(
      color: codeBlock,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
