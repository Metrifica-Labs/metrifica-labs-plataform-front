import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/narrative_model.dart';
import '../data/narratives_repository.dart';

const _typeLabels = {
  'pitch_30s': 'Pitch 30s',
  'pitch_2min': 'Pitch 2min',
  'pitch_5min': 'Pitch 5min',
  'success_case': 'Caso de Sucesso',
  'differential': 'Diferencial',
  'faq': 'FAQ',
};

const _typeColors = {
  'pitch_30s': Color(0xFF6366F1),
  'pitch_2min': Color(0xFF8B5CF6),
  'pitch_5min': Color(0xFFEC4899),
  'success_case': Color(0xFF10B981),
  'differential': Color(0xFFF59E0B),
  'faq': Color(0xFF3B82F6),
};

class NarrativesPage extends ConsumerWidget {
  const NarrativesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrativesAsync = ref.watch(narrativesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: narrativesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (narratives) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Narrativas',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 4),
                      Text('Pitches e histórias prontas para uso',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          )),
                    ],
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _addNew(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova narrativa'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                itemCount: narratives.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _NarrativeCard(narrative: narratives[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addNew(BuildContext context, WidgetRef ref) {
    // Insere um card vazio no topo em modo edição
    // Fazemos via provider temporário para não poluir o estado global
    showDialog(
      context: context,
      builder: (_) => _NewNarrativeDialog(ref: ref),
    );
  }
}

// ─── Card com edição inline ───────────────────────────────────────────────────

class _NarrativeCard extends ConsumerStatefulWidget {
  final Narrative narrative;
  const _NarrativeCard({required this.narrative});

  @override
  ConsumerState<_NarrativeCard> createState() => _NarrativeCardState();
}

class _NarrativeCardState extends ConsumerState<_NarrativeCard> {
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _contextCtrl;
  late String _type;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _resetControllers();
  }

  void _resetControllers() {
    _titleCtrl = TextEditingController(text: widget.narrative.title);
    _contentCtrl = TextEditingController(text: widget.narrative.content);
    _contextCtrl = TextEditingController(text: widget.narrative.context ?? '');
    _type = widget.narrative.type;
    _isActive = widget.narrative.isActive;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  void _startEditing() => setState(() => _editing = true);

  void _cancelEditing() {
    _titleCtrl.text = widget.narrative.title;
    _contentCtrl.text = widget.narrative.content;
    _contextCtrl.text = widget.narrative.context ?? '';
    setState(() {
      _type = widget.narrative.type;
      _isActive = widget.narrative.isActive;
      _editing = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = Narrative(
        id: widget.narrative.id,
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        type: _type,
        context: _contextCtrl.text.isEmpty ? null : _contextCtrl.text,
        isActive: _isActive,
      );
      await ref.read(narrativesRepoProvider).upsert(updated);
      ref.invalidate(narrativesProvider);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir narrativa?'),
        content: Text('A narrativa "${widget.narrative.title}" será removida permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(narrativesRepoProvider).delete(widget.narrative.id);
      ref.invalidate(narrativesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _editing ? _buildEditMode(context) : _buildViewMode(context);
  }

  Widget _buildViewMode(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColors[widget.narrative.type] ?? const Color(0xFF6366F1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _TypeBadge(type: widget.narrative.type),
                const SizedBox(width: 8),
                if (!widget.narrative.isActive)
                  _Badge(label: 'Inativo', color: Colors.grey),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Editar',
                  onPressed: _startEditing,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Excluir',
                  onPressed: _delete,
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Título
            Text(
              widget.narrative.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),

            // Conteúdo
            Text(
              widget.narrative.content,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),

            // Contexto
            if (widget.narrative.context != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.narrative.context!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
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

  Widget _buildEditMode(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do modo edição
            Row(
              children: [
                Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Editando',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    )),
                const Spacer(),
                // Switch ativo/inativo
                Row(
                  children: [
                    Text('Ativo',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                    const SizedBox(width: 6),
                    Switch.adaptive(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 16),

            // Tipo
            _EditLabel('Tipo'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
              items: _typeLabels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _typeColors[e.key],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(e.value),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 16),

            // Título
            _EditLabel('Título'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Título da narrativa',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // Conteúdo
            _EditLabel('Conteúdo'),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: null,
              minLines: 4,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Escreva o conteúdo da narrativa...',
                contentPadding: EdgeInsets.all(14),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Contexto de uso
            _EditLabel('Contexto de uso'),
            const SizedBox(height: 8),
            TextField(
              controller: _contextCtrl,
              maxLines: 2,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Quando usar esta narrativa? (opcional)',
                contentPadding: EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            // Ações
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : _cancelEditing,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Salvar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dialog só para criar nova (sem ID ainda) ─────────────────────────────────

class _NewNarrativeDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _NewNarrativeDialog({required this.ref});

  @override
  ConsumerState<_NewNarrativeDialog> createState() => _NewNarrativeDialogState();
}

class _NewNarrativeDialogState extends ConsumerState<_NewNarrativeDialog> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _contextCtrl = TextEditingController();
  String _type = 'pitch_30s';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _contentCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final n = Narrative(
        id: '',
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        type: _type,
        context: _contextCtrl.text.isEmpty ? null : _contextCtrl.text,
        isActive: true,
      );
      await ref.read(narrativesRepoProvider).upsert(n);
      ref.invalidate(narrativesProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Nova narrativa'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditLabel('Tipo'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
                items: _typeLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _typeColors[e.key],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              _EditLabel('Título *'),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Título da narrativa',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              _EditLabel('Conteúdo *'),
              const SizedBox(height: 8),
              TextField(
                controller: _contentCtrl,
                maxLines: null,
                minLines: 4,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                decoration: const InputDecoration(
                  hintText: 'Escreva o conteúdo...',
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              _EditLabel('Contexto de uso'),
              const SizedBox(height: 8),
              TextField(
                controller: _contextCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Quando usar? (opcional)',
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.add, size: 16),
          label: const Text('Criar'),
        ),
      ],
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[type] ?? const Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _typeLabels[type] ?? type,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _EditLabel extends StatelessWidget {
  final String text;
  const _EditLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
