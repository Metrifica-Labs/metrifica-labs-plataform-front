import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/post_model.dart';
import '../data/posts_repository.dart';

class EditorialPage extends ConsumerStatefulWidget {
  const EditorialPage({super.key});

  @override
  ConsumerState<EditorialPage> createState() => _EditorialPageState();
}

class _EditorialPageState extends ConsumerState<EditorialPage> {
  PostStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editorial',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Posts gerados — pipeline de publicação',
            style: TextStyle(
              fontSize: 14,
              color: onSurface.withValues(alpha: 0.45),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          _PillarDashboard(),
          const SizedBox(height: 20),
          _StatusFilterBar(
            selected: _filterStatus,
            onSelect: (s) => setState(() => _filterStatus = s),
          ),
          const SizedBox(height: 16),
          postsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
            error: (e, _) => Center(
              child: Text('Erro: $e',
                  style: TextStyle(color: onSurface.withValues(alpha: 0.5))),
            ),
            data: (posts) {
              final filtered = _filterStatus == null
                  ? posts
                  : posts.where((p) => p.status == _filterStatus).toList();
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'Nenhum post encontrado.',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: filtered
                    .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PostCard(post: p),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Pillar dashboard ─────────────────────────────────────────────────────────

class _PillarDashboard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(postsForPillarStatsProvider);
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.03),
            border: Border.all(color: onSurface.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilares — últimos 30 dias',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      border: Border.all(
                          color: primary.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 12,
                            color: onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.value}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Status filter bar ────────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final PostStatus? selected;
  final ValueChanged<PostStatus?> onSelect;

  const _StatusFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    final options = [null, ...PostStatus.values];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((s) {
          final isSelected = s == selected;
          final label = s == null ? 'Todos' : s.label;
          final color = s?.color ?? primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 130),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : onSurface.withValues(alpha: 0.04),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.4)
                        : onSurface.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? color
                        : onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Post card ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  const _PostCard({required this.post});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _expanded = false;
  bool _updating = false;

  Future<void> _changeStatus(PostStatus newStatus,
      {DateTime? scheduledAt}) async {
    setState(() => _updating = true);
    try {
      await ref.read(postsRepositoryProvider).updateStatus(
            widget.post.id,
            newStatus,
            scheduledAt: scheduledAt,
          );
      ref.invalidate(postsProvider);
      ref.invalidate(postsForPillarStatsProvider);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _updating = true);
    try {
      await ref.read(postsRepositoryProvider).delete(widget.post.id);
      ref.invalidate(postsProvider);
      ref.invalidate(postsForPillarStatsProvider);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.post.scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    await _changeStatus(PostStatus.scheduled, scheduledAt: date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final post = widget.post;
    final statusColor = post.status.color;
    final fmt = DateFormat('dd/MM/yy');

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.02),
          border: Border.all(color: outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // header
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        post.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                    if (post.pillar != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Pilar ${post.pillar}',
                          style: TextStyle(
                            fontSize: 10,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        post.content.length > 100
                            ? '${post.content.substring(0, 100)}...'
                            : post.content,
                        style: TextStyle(
                          fontSize: 12,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fmt.format(post.createdAt.toLocal()),
                      style: TextStyle(
                        fontSize: 11,
                        color: onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: onSurface.withValues(alpha: 0.25),
                    ),
                  ],
                ),
              ),
            ),
            // expanded detail
            if (_expanded) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: outline.withValues(alpha: 0.4)),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (post.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          post.imageUrl!,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 80,
                            color: onSurface.withValues(alpha: 0.04),
                            child: Center(
                              child: Text(
                                'Imagem indisponível',
                                style: TextStyle(
                                    color:
                                        onSurface.withValues(alpha: 0.3)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    MarkdownBody(
                      data: post.content,
                      styleSheet: _postMarkdownStyle(theme),
                    ),
                    const SizedBox(height: 16),
                    _ActionBar(
                      post: post,
                      updating: _updating,
                      onChangeStatus: _changeStatus,
                      onPickSchedule: _pickSchedule,
                      onDelete: _delete,
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: post.content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copiado para a área de transferência'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final PostModel post;
  final bool updating;
  final Future<void> Function(PostStatus, {DateTime? scheduledAt})
      onChangeStatus;
  final VoidCallback onPickSchedule;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  const _ActionBar({
    required this.post,
    required this.updating,
    required this.onChangeStatus,
    required this.onPickSchedule,
    required this.onDelete,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Row(
      children: [
        if (updating)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5,
                color: theme.colorScheme.primary),
          )
        else ...[
          if (post.status == PostStatus.draft)
            _ActionButton(
              label: 'Aprovar',
              icon: Icons.check_circle_outline,
              color: Colors.blue,
              onTap: () => onChangeStatus(PostStatus.approved),
            ),
          if (post.status == PostStatus.approved)
            _ActionButton(
              label: 'Agendar',
              icon: Icons.schedule_outlined,
              color: Colors.orange,
              onTap: onPickSchedule,
            ),
          if (post.status == PostStatus.scheduled)
            _ActionButton(
              label: 'Publicado',
              icon: Icons.rocket_launch_outlined,
              color: Colors.green,
              onTap: () => onChangeStatus(PostStatus.published),
            ),
        ],
        const Spacer(),
        IconButton(
          onPressed: onCopy,
          icon: const Icon(Icons.copy_outlined, size: 15),
          tooltip: 'Copiar conteúdo',
          color: onSurface.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 15),
          tooltip: 'Excluir',
          color: Colors.red.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Markdown style ───────────────────────────────────────────────────────────

MarkdownStyleSheet _postMarkdownStyle(ThemeData theme) {
  final onSurface = theme.colorScheme.onSurface;
  final surface = theme.colorScheme.surfaceContainerHighest;
  final primary = theme.colorScheme.primary;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyMedium?.copyWith(
      height: 1.7,
      color: onSurface.withValues(alpha: 0.85),
    ),
    h1: theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: onSurface,
    ),
    h2: theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: onSurface,
    ),
    h3: theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: onSurface.withValues(alpha: 0.9),
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(
      color: onSurface.withValues(alpha: 0.85),
    ),
    tableHead: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: onSurface,
    ),
    tableBody: TextStyle(
      fontSize: 13,
      color: onSurface.withValues(alpha: 0.8),
    ),
    blockquote: theme.textTheme.bodyMedium?.copyWith(
      fontStyle: FontStyle.italic,
      color: onSurface.withValues(alpha: 0.75),
    ),
    blockquoteDecoration: BoxDecoration(
      color: surface,
      border: Border(
        left: BorderSide(color: primary.withValues(alpha: 0.5), width: 3),
      ),
    ),
    code: TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      backgroundColor: surface,
      color: theme.colorScheme.secondary,
    ),
    codeblockDecoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
