import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/career_profile_model.dart';
import '../data/career_profile_repository.dart';

class CareerProfilePage extends ConsumerWidget {
  const CareerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(careerProfileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (profile) => profile == null
            ? const Center(child: Text('Nenhum perfil encontrado'))
            : _ProfileContent(profile: profile),
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final CareerProfile profile;
  const _ProfileContent({required this.profile});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  late final _nameCtrl = TextEditingController(text: widget.profile.name);
  late final _roleCtrl = TextEditingController(text: widget.profile.role);
  late final _companyCtrl = TextEditingController(text: widget.profile.company);
  late final _tierCtrl = TextEditingController(text: widget.profile.companyTier ?? '');
  late final _specCtrl = TextEditingController(text: widget.profile.specialization ?? '');
  late final _yearsInTechCtrl = TextEditingController(text: widget.profile.yearsInTech?.toString() ?? '');
  late final _yearsInSalesCtrl = TextEditingController(text: widget.profile.yearsInSales?.toString() ?? '');
  late final _goalsCtrl = TextEditingController(text: widget.profile.currentGoals ?? '');
  late final _objectiveCtrl = TextEditingController(text: widget.profile.finalObjective ?? '');
  late String _techInput = (widget.profile.technologies ?? []).join(', ');

  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _roleCtrl, _companyCtrl, _tierCtrl, _specCtrl,
      _yearsInTechCtrl, _yearsInSalesCtrl, _goalsCtrl, _objectiveCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = widget.profile.copyWith(
        name: _nameCtrl.text,
        role: _roleCtrl.text,
        company: _companyCtrl.text,
        companyTier: _tierCtrl.text.isEmpty ? null : _tierCtrl.text,
        specialization: _specCtrl.text.isEmpty ? null : _specCtrl.text,
        yearsInTech: int.tryParse(_yearsInTechCtrl.text),
        yearsInSales: int.tryParse(_yearsInSalesCtrl.text),
        currentGoals: _goalsCtrl.text.isEmpty ? null : _goalsCtrl.text,
        finalObjective: _objectiveCtrl.text.isEmpty ? null : _objectiveCtrl.text,
        technologies: _techInput
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
      );
      await ref.read(careerProfileRepositoryProvider).upsert(updated);
      ref.invalidate(careerProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Perfil de Carreira',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: const Text('Salvar'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionCard(
            title: 'Informações Básicas',
            children: [
              _row([
                _field('Nome', _nameCtrl),
                _field('Cargo', _roleCtrl),
              ]),
              _row([
                _field('Empresa', _companyCtrl),
                _field('Tier da Empresa', _tierCtrl),
              ]),
              _row([
                _field('Especialização', _specCtrl),
                _field('Anos em Tech', _yearsInTechCtrl, keyboardType: TextInputType.number),
                _field('Anos em Vendas', _yearsInSalesCtrl, keyboardType: TextInputType.number),
              ]),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tecnologias',
            children: [
              TextFormField(
                initialValue: _techInput,
                decoration: const InputDecoration(
                  labelText: 'Tecnologias (separadas por vírgula)',
                  hintText: 'AWS, Terraform, Python...',
                ),
                onChanged: (v) => _techInput = v,
                maxLines: 2,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Objetivos',
            children: [
              TextField(
                controller: _goalsCtrl,
                decoration: const InputDecoration(labelText: 'Objetivos Atuais'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _objectiveCtrl,
                decoration: const InputDecoration(labelText: 'Objetivo Final'),
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children
              .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
              .toList()
            ..removeLast(),
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
          {TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                )),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
