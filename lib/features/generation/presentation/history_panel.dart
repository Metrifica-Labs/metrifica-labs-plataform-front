import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:web/web.dart' as web;

import '../data/generation_history.dart';

void showHistoryPanel(BuildContext context) {
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
  HistoryEntry? _selected;

  @override
  Widget build(BuildContext context) {
    final histAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: const Color(0xFF0F0F18),
        child: SizedBox(
          width: 520,
          height: double.infinity,
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Row(
                  children: [
                    if (_selected != null)
                      IconButton(
                        onPressed: () => setState(() => _selected = null),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        color: Colors.white.withValues(alpha: 0.5),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    else
                      Icon(Icons.history,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(width: 10),
                    Text(
                      _selected != null ? 'Resultado' : 'Histórico',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    if (_selected == null)
                      histAsync.whenData((list) => list.isNotEmpty
                          ? TextButton(
                              onPressed: () => ref
                                  .read(historyProvider.notifier)
                                  .clear(),
                              child: Text('Limpar tudo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.white.withValues(alpha: 0.3),
                                  )),
                            )
                          : const SizedBox.shrink()).value ??
                          const SizedBox.shrink(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.white.withValues(alpha: 0.4),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Body ────────────────────────────────────────────────
              Expanded(
                child: _selected != null
                    ? _EntryDetail(
                        entry: _selected!,
                        onDelete: () {
                          ref
                              .read(historyProvider.notifier)
                              .remove(_selected!.id);
                          setState(() => _selected = null);
                        },
                      )
                    : histAsync.when(
                        loading: () => const Center(
                            child: CircularProgressIndicator()),
                        error: (e, _) =>
                            Center(child: Text('Erro: $e')),
                        data: (entries) => entries.isEmpty
                            ? _EmptyState()
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: entries.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => _EntryTile(
                                  entry: entries[i],
                                  onTap: () =>
                                      setState(() => _selected = entries[i]),
                                  onDelete: () => ref
                                      .read(historyProvider.notifier)
                                      .remove(entries[i].id),
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 40, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text('Nenhuma geração ainda',
              style: TextStyle(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy HH:mm');
    return Material(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.white.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (entry.templateName != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.templateName!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        Text(
                          fmt.format(entry.createdAt.toLocal()),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.userMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.output.length} caracteres',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(Icons.chevron_right,
                      size: 16, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryDetail extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onDelete;

  const _EntryDetail({required this.entry, required this.onDelete});

  void _downloadHtml(BuildContext context) {
    final body = md.markdownToHtml(entry.output,
        extensionSet: md.ExtensionSet.gitHubWeb);
    final fullHtml = '''<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<title>Metrifica — Output</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; max-width: 800px; margin: 48px auto; padding: 0 24px; color: #1a1a1a; line-height: 1.7; }
  h1, h2, h3 { font-weight: 700; margin-top: 2em; }
  h1 { font-size: 2em; } h2 { font-size: 1.4em; } h3 { font-size: 1.1em; }
  table { border-collapse: collapse; width: 100%; margin: 1.5em 0; }
  th, td { border: 1px solid #e0e0e0; padding: 8px 12px; text-align: left; }
  th { background: #f5f5f5; font-weight: 600; }
  code { background: #f3f3f3; padding: 2px 6px; border-radius: 4px; font-size: 0.9em; }
  pre { background: #f3f3f3; padding: 16px; border-radius: 8px; overflow-x: auto; }
  blockquote { border-left: 3px solid #ccc; margin: 0; padding-left: 16px; color: #555; }
</style>
</head>
<body>$body</body>
</html>''';

    final blob = web.Blob(
      [fullHtml.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    );
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.download = 'metrifica-output.html';
    a.click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat("dd 'de' MMMM 'de' yyyy 'às' HH:mm", 'pt_BR');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta
          Text(fmt.format(entry.createdAt.toLocal()),
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.3))),
          const SizedBox(height: 8),
          if (entry.templateName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(entry.templateName!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary.withValues(alpha: 0.8),
                    )),
              ),
            ),

          // Prompt enviado
          Text('Mensagem enviada',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.3),
                letterSpacing: 0.4,
              )),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.userMessage,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),

          const SizedBox(height: 20),

          // Output
          Row(
            children: [
              Text('Resultado',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.3),
                    letterSpacing: 0.4,
                  )),
              const Spacer(),
              IconButton(
                onPressed: () => _downloadHtml(context),
                icon: const Icon(Icons.download_outlined, size: 15),
                tooltip: 'Baixar como HTML',
                color: Colors.white.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: entry.output));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copiado'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 15),
                tooltip: 'Copiar markdown',
                color: Colors.white.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF0F0F18),
                      title: const Text('Excluir do histórico?',
                          style: TextStyle(fontSize: 15)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onDelete();
                          },
                          child: Text('Excluir',
                              style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.8))),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 15),
                tooltip: 'Excluir',
                color: Colors.white.withValues(alpha: 0.25),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MarkdownBody(
            data: entry.output,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.7, color: Colors.white.withValues(alpha: 0.75)),
              h1: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              h2: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              h3: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              code: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                color: theme.colorScheme.secondary,
              ),
              codeblockDecoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              tableHead:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tableBody: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
            ),
          ),
        ],
      ),
    );
  }
}
