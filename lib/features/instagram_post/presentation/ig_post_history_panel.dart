import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/ig_post_history.dart';
import '../data/instagram_post_notifier.dart';

void showIgPostHistoryPanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar histórico',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => const _HistorySheet(),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
      child: child,
    ),
  );
}

class _HistorySheet extends ConsumerStatefulWidget {
  const _HistorySheet();

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  IgPostHistoryEntry? _selected;

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(igPostHistoryProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: theme.colorScheme.surface,
        child: SizedBox(
          width: 420,
          height: double.infinity,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: outline.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  children: [
                    if (_selected != null)
                      IconButton(
                        onPressed: () => setState(() => _selected = null),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        color: onSurface.withValues(alpha: 0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      Icon(Icons.history,
                          size: 18, color: onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 10),
                    Text(
                      _selected != null ? 'Detalhes' : 'Histórico',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (_selected == null)
                      histAsync.whenOrNull(
                            data: (list) => list.isNotEmpty
                                ? TextButton(
                                    onPressed: () => ref
                                        .read(igPostHistoryProvider.notifier)
                                        .clear(),
                                    child: Text('Limpar',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                onSurface.withValues(alpha: 0.4))),
                                  )
                                : null,
                          ) ??
                          const SizedBox.shrink(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      color: onSurface.withValues(alpha: 0.4),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Corpo ───────────────────────────────────────────────
              Expanded(
                child: histAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                  error: (e, _) =>
                      Center(child: Text('Erro: $e', style: const TextStyle(fontSize: 13))),
                  data: (entries) {
                    if (_selected != null) {
                      return _DetailView(
                        entry: _selected!,
                        onRestore: () {
                          _restore(_selected!);
                          Navigator.of(context).pop();
                        },
                      );
                    }
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history,
                                size: 32,
                                color: onSurface.withValues(alpha: 0.15)),
                            const SizedBox(height: 10),
                            Text(
                              'Nenhum histórico ainda.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: onSurface.withValues(alpha: 0.35)),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _EntryTile(
                        entry: entries[i],
                        onTap: () => setState(() => _selected = entries[i]),
                        onRestore: () {
                          _restore(entries[i]);
                          Navigator.of(context).pop();
                        },
                        onDelete: () => ref
                            .read(igPostHistoryProvider.notifier)
                            .remove(entries[i].id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _restore(IgPostHistoryEntry entry) {
    ref.read(instagramPostProvider.notifier).restoreFromHistory(
          entry.toPostStyle(),
          entry.slides,
        );
  }
}

// ── Tile da lista ─────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final IgPostHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final dateStr = DateFormat('dd/MM/yy HH:mm').format(entry.createdAt);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: outline.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                        fontSize: 11,
                        color: onSurface.withValues(alpha: 0.4)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${entry.slides.length} slides',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: primary),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore, size: 15),
                    tooltip: 'Restaurar',
                    color: onSurface.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 15),
                    tooltip: 'Remover',
                    color: onSurface.withValues(alpha: 0.3),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (entry.briefing.isNotEmpty)
                Text(
                  entry.briefing,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: onSurface.withValues(alpha: 0.7),
                      height: 1.4),
                ),
              if (entry.briefing.isNotEmpty) const SizedBox(height: 4),
              Text(
                entry.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.4),
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detalhe de um entry ───────────────────────────────────────────────────────

class _DetailView extends StatefulWidget {
  final IgPostHistoryEntry entry;
  final VoidCallback onRestore;

  const _DetailView({required this.entry, required this.onRestore});

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  int _slide = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final slides = widget.entry.slides;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Briefing
        if (widget.entry.briefing.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: onSurface.withValues(alpha: 0.03),
              border: Border.all(color: outline.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.entry.briefing,
              style: TextStyle(
                  fontSize: 12,
                  color: onSurface.withValues(alpha: 0.65),
                  height: 1.5),
            ),
          ),

        // Navegação dos slides
        if (slides.length > 1) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(slides.length, (i) {
                  final sel = i == _slide;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('${i + 1}',
                          style: const TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (_) => setState(() => _slide = i),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],

        // Conteúdo do slide
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: slides.isEmpty
                ? Text('Sem slides.',
                    style: TextStyle(color: onSurface.withValues(alpha: 0.4)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (slides[_slide].headline.isNotEmpty)
                        Text(
                          slides[_slide].headline,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700, height: 1.3),
                        ),
                      if (slides[_slide].body.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          slides[_slide].body,
                          style: TextStyle(
                              fontSize: 13,
                              color: onSurface.withValues(alpha: 0.7),
                              height: 1.5),
                        ),
                      ],
                    ],
                  ),
          ),
        ),

        // Botão restaurar
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: widget.onRestore,
            icon: const Icon(Icons.restore, size: 16),
            label: const Text('Restaurar esta sessão',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
