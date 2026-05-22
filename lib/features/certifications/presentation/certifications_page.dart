import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/certification_model.dart';
import '../data/certifications_repository.dart';

const _statusLabels = {
  'not_started': 'Não iniciado',
  'in_progress': 'Em andamento',
  'completed': 'Concluído',
  'paused': 'Pausado',
};

const _statusColors = {
  'not_started': Colors.grey,
  'in_progress': Color(0xFF6366F1),
  'completed': Color(0xFF10B981),
  'paused': Color(0xFFF59E0B),
};

class CertificationsPage extends ConsumerWidget {
  const CertificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(certificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (certs) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Certificações',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showCertForm(context, ref, null),
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
                itemCount: certs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _CertCard(cert: certs[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCertForm(BuildContext context, WidgetRef ref, Certification? cert) {
    showDialog(
      context: context,
      builder: (_) => _CertFormDialog(cert: cert, ref: ref),
    );
  }
}

class _CertCard extends StatelessWidget {
  final Certification cert;
  final WidgetRef ref;

  const _CertCard({required this.cert, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColors[cert.status] ?? Colors.grey;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.15),
          child: Text(
            '${cert.priorityOrder}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(cert.name,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (cert.code != null) ...[
              const SizedBox(width: 8),
              Chip(
                label: Text(cert.code!,
                    style: const TextStyle(fontSize: 11)),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _statusLabels[cert.status] ?? cert.status,
                style: TextStyle(fontSize: 11, color: color),
              ),
            ),
            if (cert.targetDate != null) ...[
              const SizedBox(width: 8),
              Text('Meta: ${cert.targetDate}',
                  style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cert.topics?.isNotEmpty == true) ...[
                  Text('Tópicos',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      )),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: cert.topics!
                        .map((t) => Chip(
                              label: Text(t),
                              visualDensity: VisualDensity.compact,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (cert.notes != null)
                  Text(cert.notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      )),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _CertFormDialog(cert: cert, ref: ref),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref
                            .read(certificationsRepoProvider)
                            .delete(cert.id);
                        ref.invalidate(certificationsProvider);
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Excluir'),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CertFormDialog extends ConsumerStatefulWidget {
  final Certification? cert;
  final WidgetRef ref;

  const _CertFormDialog({this.cert, required this.ref});

  @override
  ConsumerState<_CertFormDialog> createState() => _CertFormDialogState();
}

class _CertFormDialogState extends ConsumerState<_CertFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.cert?.name ?? '');
  late final _codeCtrl = TextEditingController(text: widget.cert?.code ?? '');
  late final _orderCtrl = TextEditingController(
      text: widget.cert?.priorityOrder.toString() ?? '1');
  late final _targetCtrl =
      TextEditingController(text: widget.cert?.targetDate ?? '');
  late final _hoursCtrl =
      TextEditingController(text: widget.cert?.studyHoursDay ?? '');
  late final _notesCtrl = TextEditingController(text: widget.cert?.notes ?? '');
  late String _status = widget.cert?.status ?? 'not_started';
  late String _topicsInput = (widget.cert?.topics ?? []).join(', ');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _codeCtrl, _orderCtrl, _targetCtrl, _hoursCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final cert = Certification(
        id: widget.cert?.id ?? '',
        name: _nameCtrl.text,
        code: _codeCtrl.text.isEmpty ? null : _codeCtrl.text,
        status: _status,
        priorityOrder: int.tryParse(_orderCtrl.text) ?? 1,
        targetDate: _targetCtrl.text.isEmpty ? null : _targetCtrl.text,
        studyHoursDay: _hoursCtrl.text.isEmpty ? null : _hoursCtrl.text,
        topics: _topicsInput
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );
      await ref.read(certificationsRepoProvider).upsert(cert);
      ref.invalidate(certificationsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.cert == null ? 'Nova Certificação' : 'Editar Certificação'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome *'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      decoration: const InputDecoration(labelText: 'Código (ex: SAA-C03)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _orderCtrl,
                      decoration: const InputDecoration(labelText: 'Prioridade'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusLabels.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetCtrl,
                      decoration: const InputDecoration(labelText: 'Data Meta (YYYY-MM-DD)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hoursCtrl,
                      decoration: const InputDecoration(labelText: 'Horas/dia'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _topicsInput,
                decoration: const InputDecoration(
                    labelText: 'Tópicos (separados por vírgula)'),
                onChanged: (v) => _topicsInput = v,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notas'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
