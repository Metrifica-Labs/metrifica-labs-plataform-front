import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../instagram_post/data/instagram_post_notifier.dart';
import '../../instagram_post/data/instagram_post_style.dart';
import '../data/instagram_n3_card.dart';
import '../data/instagram_n3_chat.dart';

class InstagramN3Page extends ConsumerStatefulWidget {
  const InstagramN3Page({super.key});

  @override
  ConsumerState<InstagramN3Page> createState() => _InstagramN3PageState();
}

class _InstagramN3PageState extends ConsumerState<InstagramN3Page> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _inputFocus = FocusNode();
  bool _showScrollBtn = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final distFromBottom = _scrollCtrl.position.maxScrollExtent -
        _scrollCtrl.position.pixels;
    final shouldShow = distFromBottom > 200;
    if (shouldShow != _showScrollBtn) {
      setState(() => _showScrollBtn = shouldShow);
    }
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    ref.read(n3ChatProvider.notifier).send(text);
    _scrollToBottom();
  }

  void _quickSend(String text) {
    _inputCtrl.text = text;
    _inputFocus.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 300,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _copyResponse(BuildContext context, N3ChatMessage msg) {
    final String text;
    if (msg.post != null && msg.post!.hasCards) {
      final visible = _visibleText(msg.content);
      if (visible.isNotEmpty) {
        text = visible;
      } else {
        text = msg.post!.cards
            .map((c) => '${c.headline}\n\n${c.body}'.trim())
            .join('\n\n---\n\n');
      }
    } else {
      text = msg.content;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Resposta copiada!'),
          duration: Duration(seconds: 2)),
    );
  }

  void _sendToPost(BuildContext context, N3Post post) {
    final slides = post.cards
        .map((c) => SlideContent(headline: c.headline, body: c.body))
        .toList();
    ref.read(pendingN3SlidesProvider.notifier).state = slides;
    context.go('/instagram-post');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final chat = ref.watch(n3ChatProvider);

    ref.listen(n3ChatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) != next.messages.length ||
          next.isGenerating) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instagram N3',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Posts N3 · Bio · Legendas · Discurso',
                      style: TextStyle(
                        fontSize: 12,
                        color: onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              if (!chat.isEmpty)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(n3ChatProvider.notifier).clear(),
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: const Text('Nova conversa',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.45),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ),

        // ── Messages + floating button ────────────────────────
        Expanded(
          child: Stack(
            children: [
              chat.isEmpty
                  ? _EmptyState(onQuickSend: _quickSend)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: chat.messages.length,
                      itemBuilder: (_, i) {
                        final msg = chat.messages[i];
                        if (msg.role == N3ChatRole.user) {
                          return _UserBubble(message: msg);
                        }
                        return _AssistantBubble(
                          message: msg,
                          onCopy: () => _copyResponse(context, msg),
                          onSendToPost: msg.post?.hasCards == true
                              ? () => _sendToPost(context, msg.post!)
                              : null,
                        );
                      },
                    ),

              // Floating scroll-to-bottom button
              if (_showScrollBtn)
                Positioned(
                  bottom: 12,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showScrollBtn ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: FloatingActionButton.small(
                      heroTag: 'n3_scroll_bottom',
                      onPressed: _scrollToBottom,
                      elevation: 2,
                      backgroundColor:
                          theme.colorScheme.surface,
                      foregroundColor:
                          onSurface.withValues(alpha: 0.6),
                      child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Input ────────────────────────────────────────────────
        _ChatInput(
          controller: _inputCtrl,
          focusNode: _inputFocus,
          isGenerating: chat.isGenerating,
          onSend: _send,
        ),
      ],
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final void Function(String) onQuickSend;

  const _EmptyState({required this.onQuickSend});

  static const _suggestions = [
    'Elabore o discurso e método para o meu negócio',
    'Me dê 10 opções de bio',
    'Escreva o Post N3 1/9',
    'Crie uma legenda para o carrossel',
    'Escreva o Script Automático para Direct',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 36,
                color: onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              Text(
                'Como posso ajudar?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gere Posts N3, bios, legendas e discurso em conversa. '
                'Vá refinando conforme avança.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.4),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _suggestions.map((s) {
                  return ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onPressed: () => onQuickSend(s),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── User Bubble ──────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final N3ChatMessage message;
  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 56),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 14,
                  color: onSurface.withValues(alpha: 0.85),
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assistant Bubble ─────────────────────────────────────────────────────────

String _visibleText(String content) =>
    content.replaceAll(RegExp(r'```(?:json)?\s*[\s\S]*?```'), '').trim();

class _AssistantBubble extends StatelessWidget {
  final N3ChatMessage message;
  final VoidCallback onCopy;
  final VoidCallback? onSendToPost;

  const _AssistantBubble({
    required this.message,
    required this.onCopy,
    this.onSendToPost,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;

    final text = message.post != null
        ? _visibleText(message.content)
        : message.content;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.auto_awesome, size: 14, color: primary),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Typing indicator
                if (message.isStreaming && message.content.isEmpty)
                  _TypingIndicator()
                else if (text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.2),
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          text,
                          style: TextStyle(
                            fontSize: 14,
                            color: onSurface.withValues(alpha: 0.85),
                            height: 1.6,
                          ),
                        ),
                        if (message.isStreaming) ...[
                          const SizedBox(height: 6),
                          _StreamingCursor(),
                        ],
                      ],
                    ),
                  ),

                // Card viewer
                if (message.post != null && message.post!.hasCards) ...[
                  const SizedBox(height: 10),
                  _InlineCardViewer(post: message.post!),
                ],

                // Action buttons (copy + send to post) — só depois de finalizado
                if (!message.isStreaming) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.copy_outlined,
                        label: 'Copiar',
                        onTap: onCopy,
                      ),
                      if (onSendToPost != null) ...[
                        const SizedBox(width: 6),
                        _ActionBtn(
                          icon: Icons.open_in_new_rounded,
                          label: 'Text Post',
                          onTap: onSendToPost!,
                          highlight: true,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.colorScheme.primary.withValues(alpha: 0.75)
        : theme.colorScheme.onSurface.withValues(alpha: 0.35);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight:
                    highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color:
                  theme.colorScheme.outline.withValues(alpha: 0.2)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Text(
              'Gerando...',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamingCursor extends StatefulWidget {
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 14,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ─── Inline Card Viewer ───────────────────────────────────────────────────────

class _InlineCardViewer extends StatefulWidget {
  final N3Post post;
  const _InlineCardViewer({required this.post});

  @override
  State<_InlineCardViewer> createState() => _InlineCardViewerState();
}

class _InlineCardViewerState extends State<_InlineCardViewer> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final outline = theme.colorScheme.outline;

    final cards = widget.post.cards;
    if (_current >= cards.length) _current = cards.length - 1;
    final card = cards[_current];
    final total = cards.length;

    return Container(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.03),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Card ${card.card}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        card.objetivo,
                        style: TextStyle(
                          fontSize: 10,
                          color: onSurface.withValues(alpha: 0.4),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyCard(context, card),
                      icon: const Icon(Icons.copy_outlined, size: 13),
                      color: onSurface.withValues(alpha: 0.3),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copiar card',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SelectableText(
                  card.headline,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: onSurface.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
                if (card.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    card.body,
                    style: TextStyle(
                      fontSize: 13,
                      color: onSurface.withValues(alpha: 0.6),
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: outline.withValues(alpha: 0.15))),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: _current > 0
                      ? () => setState(() => _current--)
                      : null,
                  icon: const Icon(Icons.chevron_left, size: 16),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  color: onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 2),
                Text(
                  '${_current + 1} / $total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: _current < total - 1
                      ? () => setState(() => _current++)
                      : null,
                  icon: const Icon(Icons.chevron_right, size: 16),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  color: onSurface.withValues(alpha: 0.5),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _copyAll(context, widget.post),
                  icon: const Icon(Icons.copy_all_outlined, size: 12),
                  label: const Text('Copiar todos',
                      style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: primary.withValues(alpha: 0.7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _copyCard(BuildContext context, N3Card card) {
    Clipboard.setData(
        ClipboardData(text: '${card.headline}\n\n${card.body}'.trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Card copiado!'),
          duration: Duration(seconds: 2)),
    );
  }

  void _copyAll(BuildContext context, N3Post post) {
    final buf = StringBuffer();
    for (final c in post.cards) {
      buf.writeln('--- Card ${c.card}: ${c.objetivo} ---');
      buf.writeln(c.headline);
      if (c.body.isNotEmpty) {
        buf.writeln();
        buf.writeln(c.body);
      }
      buf.writeln();
    }
    Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Todos os cards copiados!'),
          duration: Duration(seconds: 2)),
    );
  }
}

// ─── Chat Input ───────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: outline.withValues(alpha: 0.15)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 6,
              enabled: !isGenerating,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: InputDecoration(
                hintText: 'Escreva sua solicitação...',
                hintStyle: TextStyle(
                    fontSize: 14,
                    color: onSurface.withValues(alpha: 0.3)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: outline.withValues(alpha: 0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: outline.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: primary.withValues(alpha: 0.5)),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: outline.withValues(alpha: 0.15)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            height: 40,
            child: isGenerating
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary),
                  )
                : FilledButton(
                    onPressed: onSend,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded,
                        size: 18),
                  ),
          ),
        ],
      ),
    );
  }
}
