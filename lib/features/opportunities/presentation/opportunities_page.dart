import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/opportunity_model.dart';
import '../data/opportunities_repository.dart';

const _statusColors = {
  'identified': Color(0xFF6366F1),
  'evaluating': Color(0xFF8B5CF6),
  'in_contact': Color(0xFF3B82F6),
  'negotiating': Color(0xFFF59E0B),
  'converted': Color(0xFF10B981),
  'discarded': Colors.grey,
};

const _statusLabels = {
  'identified': 'Identificado',
  'evaluating': 'Avaliando',
  'in_contact': 'Em contato',
  'negotiating': 'Negociando',
  'converted': 'Convertido',
  'discarded': 'Descartado',
};

class OpportunitiesPage extends ConsumerWidget {
  const OpportunitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oppsAsync = ref.watch(opportunitiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: oppsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (opps) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Oportunidades',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 16),
                  _activeCount(context, opps),
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
                itemCount: opps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _OpportunityCard(opp: opps[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activeCount(BuildContext context, List<Opportunity> opps) {
    final active = opps.where((o) => !['converted', 'discarded'].contains(o.status)).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$active ativas',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Opportunity? o) {
    showDialog(context: context, builder: (_) => _OpportunityFormDialog(opp: o, ref: ref));
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity opp;
  final WidgetRef ref;

  const _OpportunityCard({required this.opp, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColors[opp.status] ?? Colors.grey;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            opp.type == 'job' ? Icons.work_outline : Icons.mic_outlined,
            color: color,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(opp.companyOrEvent,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (opp.score != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Score ${opp.score}', style: TextStyle(fontSize: 11, color: color)),
              ),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_statusLabels[opp.status] ?? opp.status,
                  style: TextStyle(fontSize: 11, color: color)),
            ),
            if (opp.roleOrTheme != null) ...[
              const SizedBox(width: 8),
              Text(opp.roleOrTheme!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (opp.nextAction != null) ...[
                  Row(
                    children: [
                      Icon(Icons.arrow_forward, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Próxima ação: ${opp.nextAction}', style: theme.textTheme.bodySmall)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (opp.notes != null)
                  Text(opp.notes!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog(context: context, builder: (_) => _OpportunityFormDialog(opp: opp, ref: ref)),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(opportunitiesRepoProvider).delete(opp.id);
                        ref.invalidate(opportunitiesProvider);
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Excluir'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
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

class _OpportunityFormDialog extends ConsumerStatefulWidget {
  final Opportunity? opp;
  final WidgetRef ref;

  const _OpportunityFormDialog({this.opp, required this.ref});

  @override
  ConsumerState<_OpportunityFormDialog> createState() => _OpportunityFormDialogState();
}

class _OpportunityFormDialogState extends ConsumerState<_OpportunityFormDialog> {
  late final _companyCtrl = TextEditingController(text: widget.opp?.companyOrEvent ?? '');
  late final _roleCtrl = TextEditingController(text: widget.opp?.roleOrTheme ?? '');
  late final _sourceCtrl = TextEditingController(text: widget.opp?.source ?? '');
  late final _scoreCtrl = TextEditingController(text: widget.opp?.score?.toString() ?? '');
  late final _dateCtrl = TextEditingController(text: widget.opp?.dateIdentified ?? '');
  late final _nextActionCtrl = TextEditingController(text: widget.opp?.nextAction ?? '');
  late final _notesCtrl = TextEditingController(text: widget.opp?.notes ?? '');
  late final _outcomeCtrl = TextEditingController(text: widget.opp?.outcome ?? '');
  late String _status = widget.opp?.status ?? 'identified';
  late String _type = widget.opp?.type ?? 'job';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_companyCtrl, _roleCtrl, _sourceCtrl, _scoreCtrl, _dateCtrl, _nextActionCtrl, _notesCtrl, _outcomeCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final o = Opportunity(
        id: widget.opp?.id ?? '',
        companyOrEvent: _companyCtrl.text,
        type: _type,
        status: _status,
        roleOrTheme: _roleCtrl.text.isEmpty ? null : _roleCtrl.text,
        source: _sourceCtrl.text.isEmpty ? null : _sourceCtrl.text,
        score: int.tryParse(_scoreCtrl.text),
        dateIdentified: _dateCtrl.text.isEmpty ? null : _dateCtrl.text,
        nextAction: _nextActionCtrl.text.isEmpty ? null : _nextActionCtrl.text,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        outcome: _outcomeCtrl.text.isEmpty ? null : _outcomeCtrl.text,
      );
      await ref.read(opportunitiesRepoProvider).upsert(o);
      ref.invalidate(opportunitiesProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.opp == null ? 'Nova Oportunidade' : 'Editar Oportunidade'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'Empresa / Evento *')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'job', child: Text('Emprego')),
                      DropdownMenuItem(value: 'speaking', child: Text('Palestra')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statusLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _roleCtrl, decoration: const InputDecoration(labelText: 'Cargo / Tema'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _scoreCtrl, decoration: const InputDecoration(labelText: 'Score (0-10)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _sourceCtrl, decoration: const InputDecoration(labelText: 'Fonte'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Data identificada'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _nextActionCtrl, decoration: const InputDecoration(labelText: 'Próxima ação')),
              const SizedBox(height: 12),
              TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: _outcomeCtrl, decoration: const InputDecoration(labelText: 'Resultado final'), maxLines: 2),
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
