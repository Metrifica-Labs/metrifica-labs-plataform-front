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
        yearsInTech: double.tryParse(_yearsInTechCtrl.text),
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
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 48),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Perfil de Carreira',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 4),
                    Text('Informações sobre sua trajetória e objetivos',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        )),
                  ],
                ),
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
                  label: const Text('Salvar alterações'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Identidade profissional
            _SectionCard(
              icon: Icons.person_outline,
              title: 'Identidade Profissional',
              subtitle: 'Nome, cargo e empresa atual',
              children: [
                _FieldRow(children: [
                  _LabeledField(
                    label: 'Nome completo',
                    hint: 'Ex: João Silva',
                    controller: _nameCtrl,
                    flex: 2,
                  ),
                  _LabeledField(
                    label: 'Cargo atual',
                    hint: 'Ex: Solutions Architect',
                    controller: _roleCtrl,
                    flex: 2,
                  ),
                ]),
                const SizedBox(height: 20),
                _FieldRow(children: [
                  _LabeledField(
                    label: 'Empresa',
                    hint: 'Ex: AWS',
                    controller: _companyCtrl,
                    flex: 2,
                  ),
                  _LabeledField(
                    label: 'Tier da empresa',
                    hint: 'Ex: FAANG, Scale-up...',
                    controller: _tierCtrl,
                    flex: 1,
                  ),
                  _LabeledField(
                    label: 'Especialização',
                    hint: 'Ex: Cloud Architecture',
                    controller: _specCtrl,
                    flex: 2,
                  ),
                ]),
              ],
            ),

            const SizedBox(height: 16),

            // Experiência
            _SectionCard(
              icon: Icons.timeline_outlined,
              title: 'Experiência',
              subtitle: 'Anos de atuação em cada área',
              children: [
                _FieldRow(children: [
                  _LabeledField(
                    label: 'Anos em Tech',
                    hint: 'Ex: 8',
                    controller: _yearsInTechCtrl,
                    keyboardType: TextInputType.number,
                    flex: 1,
                    suffix: 'anos',
                  ),
                  _LabeledField(
                    label: 'Anos em Vendas / Pré-vendas',
                    hint: 'Ex: 3',
                    controller: _yearsInSalesCtrl,
                    keyboardType: TextInputType.number,
                    flex: 1,
                    suffix: 'anos',
                  ),
                  const Spacer(flex: 2),
                ]),
              ],
            ),

            const SizedBox(height: 16),

            // Tecnologias
            _SectionCard(
              icon: Icons.code_outlined,
              title: 'Stack & Tecnologias',
              subtitle: 'Ferramentas e tecnologias que domina',
              children: [
                Text(
                  'Tecnologias (separadas por vírgula)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue: _techInput,
                  decoration: InputDecoration(
                    hintText: 'AWS, Terraform, Python, Kubernetes...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: theme.textTheme.bodyMedium,
                  onChanged: (v) => _techInput = v,
                  maxLines: 2,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Objetivos
            _SectionCard(
              icon: Icons.flag_outlined,
              title: 'Objetivos',
              subtitle: 'O que você quer alcançar na sua carreira',
              children: [
                _TextAreaField(
                  label: 'Objetivos atuais',
                  hint: 'O que você está buscando nos próximos 6-12 meses...',
                  controller: _goalsCtrl,
                  minLines: 3,
                ),
                const SizedBox(height: 20),
                _TextAreaField(
                  label: 'Objetivo final de carreira',
                  hint: 'Onde você quer chegar a longo prazo...',
                  controller: _objectiveCtrl,
                  minLines: 3,
                ),
              ],
            ),
          ],
      ),
    );
  }
}

// ─── Componentes de suporte ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        )),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final List<Widget> children;
  const _FieldRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .expand((w) => [w, const SizedBox(width: 16)])
          .toList()
        ..removeLast(),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int flex;
  final String? suffix;

  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.flex = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              suffixText: suffix,
              suffixStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextAreaField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int minLines;

  const _TextAreaField({
    required this.label,
    required this.hint,
    required this.controller,
    this.minLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: null,
          minLines: minLines,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.all(16),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
