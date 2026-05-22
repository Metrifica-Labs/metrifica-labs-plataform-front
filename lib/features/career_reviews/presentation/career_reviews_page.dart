import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/career_review_model.dart';
import '../data/career_reviews_repository.dart';

class CareerReviewsPage extends ConsumerWidget {
  const CareerReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(careerReviewsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (reviews) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Revisões de Carreira',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showForm(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nova Revisão'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _ReviewCard(review: reviews[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, CareerReview? r) {
    showDialog(
      context: context,
      builder: (_) => _ReviewFormDialog(review: r, ref: ref),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final CareerReview review;
  final WidgetRef ref;

  const _ReviewCard({required this.review, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = review.alignmentScore ?? 0;
    final scoreColor = score >= 8
        ? const Color(0xFF10B981)
        : score >= 5
            ? const Color(0xFFF59E0B)
            : Colors.red.shade400;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scoreColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${review.alignmentScore ?? '-'}',
                style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
              Text('/10', style: TextStyle(color: scoreColor, fontSize: 10)),
            ],
          ),
        ),
        title: Text(
          '${review.year} Q${review.quarter}',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: review.completedAt != null
            ? Text('Concluído em ${review.completedAt!.substring(0, 10)}',
                style: theme.textTheme.bodySmall)
            : Text('Em andamento', style: theme.textTheme.bodySmall),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (review.technicalProgress != null)
                  _section(context, 'Progresso Técnico', review.technicalProgress!, Icons.code_outlined),
                if (review.linkedinSummary != null)
                  _section(context, 'LinkedIn', review.linkedinSummary!, Icons.bar_chart_outlined),
                if (review.opportunitiesSummary != null)
                  _section(context, 'Oportunidades', review.opportunitiesSummary!, Icons.work_outline),
                if (review.adjustmentsNeeded != null)
                  _section(context, 'Ajustes Necessários', review.adjustmentsNeeded!, Icons.tune_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _ReviewFormDialog(review: review, ref: ref),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(careerReviewsRepoProvider).delete(review.id);
                        ref.invalidate(careerReviewsProvider);
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

  Widget _section(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ReviewFormDialog extends ConsumerStatefulWidget {
  final CareerReview? review;
  final WidgetRef ref;

  const _ReviewFormDialog({this.review, required this.ref});

  @override
  ConsumerState<_ReviewFormDialog> createState() => _ReviewFormDialogState();
}

class _ReviewFormDialogState extends ConsumerState<_ReviewFormDialog> {
  late final _yearCtrl = TextEditingController(text: widget.review?.year.toString() ?? DateTime.now().year.toString());
  late final _quarterCtrl = TextEditingController(text: widget.review?.quarter.toString() ?? '1');
  late final _scoreCtrl = TextEditingController(text: widget.review?.alignmentScore?.toString() ?? '');
  late final _techCtrl = TextEditingController(text: widget.review?.technicalProgress ?? '');
  late final _linkedinCtrl = TextEditingController(text: widget.review?.linkedinSummary ?? '');
  late final _oppsCtrl = TextEditingController(text: widget.review?.opportunitiesSummary ?? '');
  late final _adjustmentsCtrl = TextEditingController(text: widget.review?.adjustmentsNeeded ?? '');
  late final _completedCtrl = TextEditingController(text: widget.review?.completedAt?.substring(0, 10) ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_yearCtrl, _quarterCtrl, _scoreCtrl, _techCtrl, _linkedinCtrl, _oppsCtrl, _adjustmentsCtrl, _completedCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = CareerReview(
        id: widget.review?.id ?? '',
        year: int.tryParse(_yearCtrl.text) ?? DateTime.now().year,
        quarter: int.tryParse(_quarterCtrl.text) ?? 1,
        alignmentScore: int.tryParse(_scoreCtrl.text),
        technicalProgress: _techCtrl.text.isEmpty ? null : _techCtrl.text,
        linkedinSummary: _linkedinCtrl.text.isEmpty ? null : _linkedinCtrl.text,
        opportunitiesSummary: _oppsCtrl.text.isEmpty ? null : _oppsCtrl.text,
        adjustmentsNeeded: _adjustmentsCtrl.text.isEmpty ? null : _adjustmentsCtrl.text,
        completedAt: _completedCtrl.text.isEmpty ? null : _completedCtrl.text,
      );
      await ref.read(careerReviewsRepoProvider).upsert(r);
      ref.invalidate(careerReviewsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.review == null ? 'Nova Revisão' : 'Editar Revisão'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(child: TextField(controller: _yearCtrl, decoration: const InputDecoration(labelText: 'Ano'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _quarterCtrl, decoration: const InputDecoration(labelText: 'Trimestre (1-4)'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _scoreCtrl, decoration: const InputDecoration(labelText: 'Alinhamento (0-10)'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _techCtrl, decoration: const InputDecoration(labelText: 'Progresso Técnico'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: _linkedinCtrl, decoration: const InputDecoration(labelText: 'Resumo LinkedIn'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: _oppsCtrl, decoration: const InputDecoration(labelText: 'Resumo Oportunidades'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: _adjustmentsCtrl, decoration: const InputDecoration(labelText: 'Ajustes Necessários'), maxLines: 3),
              const SizedBox(height: 12),
              TextField(controller: _completedCtrl, decoration: const InputDecoration(labelText: 'Data de Conclusão (YYYY-MM-DD)')),
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
