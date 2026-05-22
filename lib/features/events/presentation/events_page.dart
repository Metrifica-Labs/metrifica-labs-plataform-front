import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/event_model.dart';
import '../data/events_repository.dart';

const _typeLabels = {
  'talk': 'Palestra',
  'attendance': 'Participação',
  'workshop': 'Workshop',
};

const _typeColors = {
  'talk': Color(0xFF6366F1),
  'attendance': Color(0xFF3B82F6),
  'workshop': Color(0xFF10B981),
};

class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (events) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Eventos',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  _typeStats(context, events),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showForm(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _EventCard(event: events[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeStats(BuildContext context, List<Event> events) {
    final talks = events.where((e) => e.type == 'talk').length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$talks palestras',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Event? e) {
    showDialog(context: context, builder: (_) => _EventFormDialog(event: e, ref: ref));
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final WidgetRef ref;

  const _EventCard({required this.event, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColors[event.type] ?? Colors.grey;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            event.type == 'talk'
                ? Icons.mic_outlined
                : event.type == 'workshop'
                    ? Icons.construction_outlined
                    : Icons.event_outlined,
            color: color,
            size: 20,
          ),
        ),
        title: Text(event.name,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_typeLabels[event.type] ?? event.type,
                      style: TextStyle(fontSize: 11, color: color)),
                ),
                if (event.date != null) ...[
                  const SizedBox(width: 8),
                  Text(event.date!.substring(0, 10), style: theme.textTheme.bodySmall),
                ],
                if (event.location != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.location_on_outlined, size: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  Text(event.location!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
            if (event.audienceSize != null)
              Text('${event.audienceSize} pessoas', style: theme.textTheme.bodySmall),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _EventFormDialog(event: event, ref: ref),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              onPressed: () async {
                await ref.read(eventsRepoProvider).delete(event.id);
                ref.invalidate(eventsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventFormDialog extends ConsumerStatefulWidget {
  final Event? event;
  final WidgetRef ref;

  const _EventFormDialog({this.event, required this.ref});

  @override
  ConsumerState<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends ConsumerState<_EventFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.event?.name ?? '');
  late final _themeCtrl = TextEditingController(text: widget.event?.theme ?? '');
  late final _dateCtrl = TextEditingController(text: widget.event?.date?.substring(0, 10) ?? '');
  late final _locationCtrl = TextEditingController(text: widget.event?.location ?? '');
  late final _audienceCtrl = TextEditingController(text: widget.event?.audienceSize?.toString() ?? '');
  late final _notesCtrl = TextEditingController(text: widget.event?.notes ?? '');
  late String _type = widget.event?.type ?? 'attendance';
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _themeCtrl, _dateCtrl, _locationCtrl, _audienceCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final e = Event(
        id: widget.event?.id ?? '',
        name: _nameCtrl.text,
        type: _type,
        theme: _themeCtrl.text.isEmpty ? null : _themeCtrl.text,
        date: _dateCtrl.text.isEmpty ? null : _dateCtrl.text,
        location: _locationCtrl.text.isEmpty ? null : _locationCtrl.text,
        audienceSize: int.tryParse(_audienceCtrl.text),
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );
      await ref.read(eventsRepoProvider).upsert(e);
      ref.invalidate(eventsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Novo Evento' : 'Editar Evento'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome *')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: _typeLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: _themeCtrl, decoration: const InputDecoration(labelText: 'Tema')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _dateCtrl, decoration: const InputDecoration(labelText: 'Data (YYYY-MM-DD)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _audienceCtrl, decoration: const InputDecoration(labelText: 'Audiência'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Local')),
              const SizedBox(height: 12),
              TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
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
