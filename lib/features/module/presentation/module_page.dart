import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/module_model.dart';
import '../../../core/repositories/modules_repository.dart';

class ModulePage extends ConsumerWidget {
  final String slug;
  const ModulePage({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moduleBySlugProvider(slug));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar módulo: $e')),
      data: (module) {
        if (module == null) {
          return const Center(child: Text('Módulo não encontrado.'));
        }
        return _ModuleView(module: module);
      },
    );
  }
}

class _ModuleView extends ConsumerStatefulWidget {
  final ModuleModel module;
  const _ModuleView({required this.module});

  @override
  ConsumerState<_ModuleView> createState() => _ModuleViewState();
}

class _ModuleViewState extends ConsumerState<_ModuleView> {
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _contentCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.module.content ?? '');
    _nameCtrl = TextEditingController(text: widget.module.name);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = ModuleModel(
        id: widget.module.id,
        slug: widget.module.slug,
        name: _nameCtrl.text.trim().isEmpty ? widget.module.name : _nameCtrl.text.trim(),
        content: _contentCtrl.text,
        moduleRef: widget.module.moduleRef,
      );
      await ref.read(modulesRepositoryProvider).upsert(updated);
      ref.invalidate(moduleBySlugProvider(widget.module.slug));
      ref.invalidate(modulesProvider);
      setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancel() {
    _contentCtrl.text = widget.module.content ?? '';
    _nameCtrl.text = widget.module.name;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.module.moduleRef != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Módulo ${widget.module.moduleRef}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    if (_editing)
                      TextField(
                        controller: _nameCtrl,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0, vertical: 4),
                          border: InputBorder.none,
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: primary.withValues(alpha: 0.5)),
                          ),
                        ),
                      )
                    else
                      Text(
                        widget.module.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Botões de ação
              if (_editing) ...[
                TextButton(
                  onPressed: _saving ? null : _cancel,
                  child: Text('Cancelar',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4))),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white))
                      : const Icon(Icons.check, size: 14),
                  label: Text(_saving ? 'Salvando...' : 'Salvar',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10)),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Editar',
                      style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.6),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Conteúdo ──────────────────────────────────────────────────
          Expanded(
            child: _editing
                ? _Editor(controller: _contentCtrl)
                : _Viewer(content: widget.module.content),
          ),
        ],
      ),
    );
  }
}

// ── Viewer (read-only markdown) ───────────────────────────────────────────────

class _Viewer extends StatelessWidget {
  final String? content;
  const _Viewer({this.content});

  @override
  Widget build(BuildContext context) {
    if (content == null || content!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined,
                size: 32, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 10),
            Text('Este módulo ainda não tem conteúdo.',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.3))),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    return Markdown(
      data: content!,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(
            height: 1.7, color: Colors.white.withValues(alpha: 0.75)),
        h1: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        tableHead:
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tableBody: TextStyle(
            fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: Colors.white.withValues(alpha: 0.5)),
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
      ),
    );
  }
}

// ── Editor (markdown raw) ─────────────────────────────────────────────────────

class _Editor extends StatefulWidget {
  final TextEditingController controller;
  const _Editor({required this.controller});

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  bool _preview = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Row(
          children: [
            _ToolbarBtn(
              label: 'Editar',
              active: !_preview,
              onTap: () => setState(() => _preview = false),
            ),
            const SizedBox(width: 4),
            _ToolbarBtn(
              label: 'Preview',
              active: _preview,
              onTap: () => setState(() => _preview = true),
            ),
            const Spacer(),
            Text(
              'Markdown',
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.2)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _preview
              ? Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _Viewer(content: widget.controller.text),
                )
              : TextField(
                  controller: widget.controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: primary.withValues(alpha: 0.4)),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? primary.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.07),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? primary : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
