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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Narrativas',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showForm(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: narratives.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _NarrativeCard(narrative: narratives[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Narrative? n) {
    showDialog(
      context: context,
      builder: (_) => _NarrativeFormDialog(narrative: n, ref: ref),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final Narrative narrative;
  final WidgetRef ref;

  const _NarrativeCard({required this.narrative, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColors[narrative.type] ?? const Color(0xFF6366F1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_typeLabels[narrative.type] ?? narrative.type,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                if (!narrative.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Inativo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => _NarrativeFormDialog(narrative: narrative, ref: ref),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    await ref.read(narrativesRepoProvider).delete(narrative.id);
                    ref.invalidate(narrativesProvider);
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text(''),
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(narrative.title,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(narrative.content, style: theme.textTheme.bodySmall),
            if (narrative.context != null) ...[
              const SizedBox(height: 8),
              Text('Contexto: ${narrative.context}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _NarrativeFormDialog extends ConsumerStatefulWidget {
  final Narrative? narrative;
  final WidgetRef ref;

  const _NarrativeFormDialog({this.narrative, required this.ref});

  @override
  ConsumerState<_NarrativeFormDialog> createState() => _NarrativeFormDialogState();
}

class _NarrativeFormDialogState extends ConsumerState<_NarrativeFormDialog> {
  late final _titleCtrl = TextEditingController(text: widget.narrative?.title ?? '');
  late final _contentCtrl = TextEditingController(text: widget.narrative?.content ?? '');
  late final _contextCtrl = TextEditingController(text: widget.narrative?.context ?? '');
  late String _type = widget.narrative?.type ?? 'pitch_30s';
  late bool _isActive = widget.narrative?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _contextCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final n = Narrative(
        id: widget.narrative?.id ?? '',
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        type: _type,
        context: _contextCtrl.text.isEmpty ? null : _contextCtrl.text,
        isActive: _isActive,
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
    return AlertDialog(
      title: Text(widget.narrative == null ? 'Nova Narrativa' : 'Editar Narrativa'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _typeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Título *')),
              const SizedBox(height: 12),
              TextField(controller: _contentCtrl, decoration: const InputDecoration(labelText: 'Conteúdo *'), maxLines: 6),
              const SizedBox(height: 12),
              TextField(controller: _contextCtrl, decoration: const InputDecoration(labelText: 'Contexto de uso'), maxLines: 2),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Ativo'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Salvar'),
        ),
      ],
    );
  }
}
