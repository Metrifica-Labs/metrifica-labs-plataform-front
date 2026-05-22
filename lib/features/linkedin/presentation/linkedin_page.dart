import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/linkedin_model.dart';
import '../data/linkedin_repository.dart';

class LinkedinPage extends ConsumerWidget {
  const LinkedinPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(linkedinMetricsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: metricsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (metrics) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    Text('LinkedIn Metrics',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => _showForm(context, ref, null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Novo Mês'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (metrics.isNotEmpty)
                _StatsOverview(metrics: metrics.first),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: metrics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _MetricsCard(metric: metrics[i], ref: ref),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, LinkedinMetrics? m) {
    showDialog(
      context: context,
      builder: (_) => _MetricsFormDialog(metric: m, ref: ref),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  final LinkedinMetrics metrics;

  const _StatsOverview({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatChip(
            label: 'Seguidores',
            value: '${metrics.followers ?? 0}',
            icon: Icons.people_outline,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: 'Posts',
            value: '${metrics.postsPublished ?? 0}',
            icon: Icons.article_outlined,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: 'Impressões Médias',
            value: '${metrics.avgImpressions ?? 0}',
            icon: Icons.visibility_outlined,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _StatChip(
            label: 'Novos Contatos',
            value: '${metrics.newRelevantContacts ?? 0}',
            icon: Icons.connect_without_contact_outlined,
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: color,
                      )),
                  Text(label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final LinkedinMetrics metric;
  final WidgetRef ref;

  const _MetricsCard({required this.metric, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(metric.month,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${metric.followers ?? 0} seguidores • ${metric.postsPublished ?? 0} posts • ${metric.avgImpressions ?? 0} impressões médias',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (metric.whatWorked != null) ...[
                  _infoRow(context, 'O que funcionou', metric.whatWorked!, Icons.thumb_up_outlined, const Color(0xFF10B981)),
                  const SizedBox(height: 8),
                ],
                if (metric.whatDidnt != null) ...[
                  _infoRow(context, 'O que não funcionou', metric.whatDidnt!, Icons.thumb_down_outlined, Colors.red.shade400),
                  const SizedBox(height: 8),
                ],
                if (metric.nextMonthAdjustment != null) ...[
                  _infoRow(context, 'Ajuste pro próximo mês', metric.nextMonthAdjustment!, Icons.arrow_forward_outlined, const Color(0xFF6366F1)),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _MetricsFormDialog(metric: metric, ref: ref),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(linkedinRepoProvider).delete(metric.id);
                        ref.invalidate(linkedinMetricsProvider);
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

  Widget _infoRow(BuildContext context, String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
              Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricsFormDialog extends ConsumerStatefulWidget {
  final LinkedinMetrics? metric;
  final WidgetRef ref;

  const _MetricsFormDialog({this.metric, required this.ref});

  @override
  ConsumerState<_MetricsFormDialog> createState() => _MetricsFormDialogState();
}

class _MetricsFormDialogState extends ConsumerState<_MetricsFormDialog> {
  late final _monthCtrl = TextEditingController(text: widget.metric?.month ?? '');
  late final _followersCtrl = TextEditingController(text: widget.metric?.followers?.toString() ?? '');
  late final _postsCtrl = TextEditingController(text: widget.metric?.postsPublished?.toString() ?? '');
  late final _impressionsCtrl = TextEditingController(text: widget.metric?.avgImpressions?.toString() ?? '');
  late final _contactsCtrl = TextEditingController(text: widget.metric?.newRelevantContacts?.toString() ?? '');
  late final _recruiterCtrl = TextEditingController(text: widget.metric?.recruiterOpportunities?.toString() ?? '');
  late final _topPostCtrl = TextEditingController(text: widget.metric?.topPost ?? '');
  late final _bottomPostCtrl = TextEditingController(text: widget.metric?.bottomPost ?? '');
  late final _whatWorkedCtrl = TextEditingController(text: widget.metric?.whatWorked ?? '');
  late final _whatDidntCtrl = TextEditingController(text: widget.metric?.whatDidnt ?? '');
  late final _adjustmentCtrl = TextEditingController(text: widget.metric?.nextMonthAdjustment ?? '');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_monthCtrl, _followersCtrl, _postsCtrl, _impressionsCtrl, _contactsCtrl, _recruiterCtrl, _topPostCtrl, _bottomPostCtrl, _whatWorkedCtrl, _whatDidntCtrl, _adjustmentCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final m = LinkedinMetrics(
        id: widget.metric?.id ?? '',
        month: _monthCtrl.text,
        followers: int.tryParse(_followersCtrl.text),
        postsPublished: int.tryParse(_postsCtrl.text),
        avgImpressions: int.tryParse(_impressionsCtrl.text),
        newRelevantContacts: int.tryParse(_contactsCtrl.text),
        recruiterOpportunities: int.tryParse(_recruiterCtrl.text),
        topPost: _topPostCtrl.text.isEmpty ? null : _topPostCtrl.text,
        bottomPost: _bottomPostCtrl.text.isEmpty ? null : _bottomPostCtrl.text,
        whatWorked: _whatWorkedCtrl.text.isEmpty ? null : _whatWorkedCtrl.text,
        whatDidnt: _whatDidntCtrl.text.isEmpty ? null : _whatDidntCtrl.text,
        nextMonthAdjustment: _adjustmentCtrl.text.isEmpty ? null : _adjustmentCtrl.text,
      );
      await ref.read(linkedinRepoProvider).upsert(m);
      ref.invalidate(linkedinMetricsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.metric == null ? 'Novo Mês' : 'Editar Métricas'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _monthCtrl,
                decoration: const InputDecoration(labelText: 'Mês (ex: 2025-01)'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _followersCtrl, decoration: const InputDecoration(labelText: 'Seguidores'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _postsCtrl, decoration: const InputDecoration(labelText: 'Posts publicados'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _impressionsCtrl, decoration: const InputDecoration(labelText: 'Impressões médias'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _contactsCtrl, decoration: const InputDecoration(labelText: 'Novos contatos'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _recruiterCtrl, decoration: const InputDecoration(labelText: 'Oport. recrutadores'), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: _whatWorkedCtrl, decoration: const InputDecoration(labelText: 'O que funcionou'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: _whatDidntCtrl, decoration: const InputDecoration(labelText: 'O que não funcionou'), maxLines: 2),
              const SizedBox(height: 12),
              TextField(controller: _adjustmentCtrl, decoration: const InputDecoration(labelText: 'Ajuste pro próximo mês'), maxLines: 2),
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
