import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_model.dart';
import '../data/posts_repository.dart';

const _statusColors = {
  'draft': Color(0xFFF59E0B),
  'published': Color(0xFF10B981),
  'archived': Colors.grey,
};

const _statusLabels = {
  'draft': 'Rascunho',
  'published': 'Publicado',
  'archived': 'Arquivado',
};

const _pillarLabels = {
  'genai_avancado': 'GenAI Avançado',
  'aceleracao_processos': 'Aceleração de Processos',
  'ia_na_pratica': 'IA na Prática',
  'ai_first': 'AI First',
};

class PostsPage extends ConsumerWidget {
  const PostsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(postsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (posts) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text('Posts',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 16),
                  _countBadge(context, posts, 'draft'),
                  const SizedBox(width: 8),
                  _countBadge(context, posts, 'published'),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => _showForm(context, ref, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Novo Post'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _PostCard(post: posts[i], ref: ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(BuildContext context, List<Post> posts, String status) {
    final count = posts.where((p) => p.status == status).length;
    final color = _statusColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count ${_statusLabels[status]}',
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Post? post) {
    showDialog(
      context: context,
      builder: (_) => _PostFormDialog(post: post, ref: ref),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final WidgetRef ref;

  const _PostCard({required this.post, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColors[post.status] ?? Colors.grey;

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
            post.status == 'published'
                ? Icons.check_circle_outline
                : Icons.edit_note,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          post.title ?? post.content.substring(0, post.content.length.clamp(0, 60)),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_statusLabels[post.status] ?? post.status,
                  style: TextStyle(fontSize: 11, color: color)),
            ),
            if (post.pillar != null) ...[
              const SizedBox(width: 8),
              Text(_pillarLabels[post.pillar] ?? post.pillar!,
                  style: theme.textTheme.bodySmall),
            ],
            if (post.publishedAt != null) ...[
              const SizedBox(width: 8),
              Text(post.publishedAt!.substring(0, 10),
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
                Text(post.content, style: theme.textTheme.bodySmall),
                if (post.status == 'published') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statChip(Icons.visibility_outlined, '${post.impressions ?? 0}', theme),
                      const SizedBox(width: 8),
                      _statChip(Icons.favorite_border, '${post.reactions ?? 0}', theme),
                      const SizedBox(width: 8),
                      _statChip(Icons.comment_outlined, '${post.comments ?? 0}', theme),
                      const SizedBox(width: 8),
                      _statChip(Icons.repeat_outlined, '${post.reposts ?? 0}', theme),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => _PostFormDialog(post: post, ref: ref),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Editar'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(postsRepoProvider).delete(post.id);
                        ref.invalidate(postsProvider);
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

  Widget _statChip(IconData icon, String value, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _PostFormDialog extends ConsumerStatefulWidget {
  final Post? post;
  final WidgetRef ref;

  const _PostFormDialog({this.post, required this.ref});

  @override
  ConsumerState<_PostFormDialog> createState() => _PostFormDialogState();
}

class _PostFormDialogState extends ConsumerState<_PostFormDialog> {
  late final _titleCtrl = TextEditingController(text: widget.post?.title ?? '');
  late final _contentCtrl = TextEditingController(text: widget.post?.content ?? '');
  late final _imagePromptCtrl = TextEditingController(text: widget.post?.imagePrompt ?? '');
  late final _publishedAtCtrl = TextEditingController(text: widget.post?.publishedAt?.substring(0, 10) ?? '');
  late final _impressionsCtrl = TextEditingController(text: widget.post?.impressions?.toString() ?? '');
  late final _reactionsCtrl = TextEditingController(text: widget.post?.reactions?.toString() ?? '');
  late final _commentsCtrl = TextEditingController(text: widget.post?.comments?.toString() ?? '');
  late final _repostsCtrl = TextEditingController(text: widget.post?.reposts?.toString() ?? '');
  late String _status = widget.post?.status ?? 'draft';
  late String _type = widget.post?.type ?? 'general';
  late String? _pillar = widget.post?.pillar;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_titleCtrl, _contentCtrl, _imagePromptCtrl, _publishedAtCtrl, _impressionsCtrl, _reactionsCtrl, _commentsCtrl, _repostsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final post = Post(
        id: widget.post?.id ?? '',
        title: _titleCtrl.text.isEmpty ? null : _titleCtrl.text,
        content: _contentCtrl.text,
        status: _status,
        type: _type,
        pillar: _pillar,
        imagePrompt: _imagePromptCtrl.text.isEmpty ? null : _imagePromptCtrl.text,
        publishedAt: _publishedAtCtrl.text.isEmpty ? null : _publishedAtCtrl.text,
        impressions: int.tryParse(_impressionsCtrl.text),
        reactions: int.tryParse(_reactionsCtrl.text),
        comments: int.tryParse(_commentsCtrl.text),
        reposts: int.tryParse(_repostsCtrl.text),
      );
      await ref.read(postsRepoProvider).upsert(post);
      ref.invalidate(postsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.post == null ? 'Novo Post' : 'Editar Post'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Título (opcional)')),
              const SizedBox(height: 12),
              TextField(controller: _contentCtrl, decoration: const InputDecoration(labelText: 'Conteúdo *'), maxLines: 6),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Rascunho')),
                      DropdownMenuItem(value: 'published', child: Text('Publicado')),
                      DropdownMenuItem(value: 'archived', child: Text('Arquivado')),
                    ],
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('Geral')),
                      DropdownMenuItem(value: 'event', child: Text('Evento')),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _pillar,
                decoration: const InputDecoration(labelText: 'Pilar'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Nenhum')),
                  ..._pillarLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
                ],
                onChanged: (v) => setState(() => _pillar = v),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: _publishedAtCtrl, decoration: const InputDecoration(labelText: 'Publicado em (YYYY-MM-DD)'))),
              ]),
              if (_status == 'published') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: _impressionsCtrl, decoration: const InputDecoration(labelText: 'Impressões'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _reactionsCtrl, decoration: const InputDecoration(labelText: 'Reações'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _commentsCtrl, decoration: const InputDecoration(labelText: 'Comentários'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _repostsCtrl, decoration: const InputDecoration(labelText: 'Reposts'), keyboardType: TextInputType.number)),
                ]),
              ],
              const SizedBox(height: 12),
              TextField(controller: _imagePromptCtrl, decoration: const InputDecoration(labelText: 'Prompt de Imagem'), maxLines: 2),
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
