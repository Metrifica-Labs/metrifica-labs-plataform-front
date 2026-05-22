import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/networking_model.dart';
import '../data/networking_repository.dart';

const _profileLabels = {
  'aws_sa_tam': 'AWS SA / TAM',
  'cto_tech_leader': 'CTO / Tech Leader',
  'technical_recruiter': 'Recrutador Técnico',
  'peer_architect': 'Arquiteto Par',
  'event_organizer': 'Org. Eventos',
  'other': 'Outro',
};

const _profileColors = {
  'aws_sa_tam': Color(0xFFF59E0B),
  'cto_tech_leader': Color(0xFF6366F1),
  'technical_recruiter': Color(0xFF10B981),
  'peer_architect': Color(0xFF8B5CF6),
  'event_organizer': Color(0xFF3B82F6),
  'other': Colors.grey,
};

class NetworkingPage extends ConsumerWidget {
  const NetworkingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(networkingContactsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (contacts) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Networking',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Text('${contacts.length} contatos',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      )),
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
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _ContactCard(contact: contacts[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, NetworkingContact? c) {
    showDialog(context: context, builder: (_) => _ContactFormDialog(contact: c, ref: ref));
  }
}

class _ContactCard extends StatelessWidget {
  final NetworkingContact contact;
  final WidgetRef ref;

  const _ContactCard({required this.contact, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _profileColors[contact.profileType] ?? Colors.grey;
    final initials = contact.name.split(' ').take(2).map((e) => e[0].toUpperCase()).join();

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withOpacity(0.15),
          child: Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ),
        title: Row(
          children: [
            Text(contact.name,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (contact.generatedOpportunity == true) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.role != null || contact.company != null)
              Text('${contact.role ?? ''}${contact.role != null && contact.company != null ? ' · ' : ''}${contact.company ?? ''}',
                  style: theme.textTheme.bodySmall),
            if (contact.profileType != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_profileLabels[contact.profileType] ?? contact.profileType!,
                    style: TextStyle(fontSize: 11, color: color)),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (contact.linkedinUrl != null)
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () => launchUrl(Uri.parse(contact.linkedinUrl!)),
                tooltip: 'Abrir LinkedIn',
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _ContactFormDialog(contact: contact, ref: ref),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              onPressed: () async {
                await ref.read(networkingRepoProvider).delete(contact.id);
                ref.invalidate(networkingContactsProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactFormDialog extends ConsumerStatefulWidget {
  final NetworkingContact? contact;
  final WidgetRef ref;

  const _ContactFormDialog({this.contact, required this.ref});

  @override
  ConsumerState<_ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends ConsumerState<_ContactFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.contact?.name ?? '');
  late final _roleCtrl = TextEditingController(text: widget.contact?.role ?? '');
  late final _companyCtrl = TextEditingController(text: widget.contact?.company ?? '');
  late final _linkedinCtrl = TextEditingController(text: widget.contact?.linkedinUrl ?? '');
  late final _howMetCtrl = TextEditingController(text: widget.contact?.howMet ?? '');
  late final _firstContactCtrl = TextEditingController(text: widget.contact?.firstContactDate ?? '');
  late final _lastContactCtrl = TextEditingController(text: widget.contact?.lastContactDate ?? '');
  late final _relationshipCtrl = TextEditingController(text: widget.contact?.relationshipStatus ?? '');
  late final _notesCtrl = TextEditingController(text: widget.contact?.notes ?? '');
  late String? _profileType = widget.contact?.profileType;
  late bool _generatedOpportunity = widget.contact?.generatedOpportunity ?? false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _roleCtrl, _companyCtrl, _linkedinCtrl, _howMetCtrl, _firstContactCtrl, _lastContactCtrl, _relationshipCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final c = NetworkingContact(
        id: widget.contact?.id ?? '',
        name: _nameCtrl.text,
        role: _roleCtrl.text.isEmpty ? null : _roleCtrl.text,
        company: _companyCtrl.text.isEmpty ? null : _companyCtrl.text,
        profileType: _profileType,
        linkedinUrl: _linkedinCtrl.text.isEmpty ? null : _linkedinCtrl.text,
        howMet: _howMetCtrl.text.isEmpty ? null : _howMetCtrl.text,
        firstContactDate: _firstContactCtrl.text.isEmpty ? null : _firstContactCtrl.text,
        lastContactDate: _lastContactCtrl.text.isEmpty ? null : _lastContactCtrl.text,
        relationshipStatus: _relationshipCtrl.text.isEmpty ? null : _relationshipCtrl.text,
        generatedOpportunity: _generatedOpportunity,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      );
      await ref.read(networkingRepoProvider).upsert(c);
      ref.invalidate(networkingContactsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.contact == null ? 'Novo Contato' : 'Editar Contato'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome *')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _roleCtrl, decoration: const InputDecoration(labelText: 'Cargo'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'Empresa'))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _profileType,
                decoration: const InputDecoration(labelText: 'Tipo de Perfil'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhum')),
                  ..._profileLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                onChanged: (v) => setState(() => _profileType = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: _linkedinCtrl, decoration: const InputDecoration(labelText: 'LinkedIn URL')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _firstContactCtrl, decoration: const InputDecoration(labelText: 'Primeiro contato'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _lastContactCtrl, decoration: const InputDecoration(labelText: 'Último contato'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _howMetCtrl, decoration: const InputDecoration(labelText: 'Como se conheceram')),
              const SizedBox(height: 12),
              TextField(controller: _relationshipCtrl, decoration: const InputDecoration(labelText: 'Status do relacionamento')),
              const SizedBox(height: 12),
              TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notas'), maxLines: 3),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Gerou oportunidade'),
                value: _generatedOpportunity,
                onChanged: (v) => setState(() => _generatedOpportunity = v),
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
