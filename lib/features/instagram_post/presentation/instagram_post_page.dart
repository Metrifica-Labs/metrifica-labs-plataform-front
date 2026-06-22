import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/providers/organization_provider.dart';
import '../../generation/data/generation_notifier.dart';
import '../../generation/data/generation_state.dart';
import '../data/ig_post_history.dart';
import '../data/instagram_connection_repository.dart';
import '../data/instagram_post_notifier.dart';
import '../data/instagram_post_style.dart';
import '../data/instagram_publish_repository.dart';
import 'ig_post_history_panel.dart';
import 'logo_image.dart';
import 'post_canvas.dart';
import 'post_canvas_type2.dart';
import 'post_canvas_type3.dart';
import 'post_canvas_type4.dart';
import 'post_export.dart';

const _flowSlug = 'instagram-text-post';

class InstagramPostPage extends ConsumerStatefulWidget {
  const InstagramPostPage({super.key});

  @override
  ConsumerState<InstagramPostPage> createState() => _InstagramPostPageState();
}

class _InstagramPostPageState extends ConsumerState<InstagramPostPage> {
  final _briefingCtrl = TextEditingController();
  final _boundaryKey = GlobalKey();

  int _current = 0;
  bool _exporting = false;
  String? _appliedOutput;
  bool _savedToHistory = false;
  bool _debugRestored = false;
  bool _styleLoaded = false;
  bool _pendingApplied = false;
  Timer? _autoSaveTimer;
  DateTime? _lastAutoSave;

  @override
  void initState() {
    super.initState();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final style = ref.read(instagramPostProvider);
      await saveStyleToPrefs(style);
      if (mounted) setState(() => _lastAutoSave = DateTime.now());
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _briefingCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pendingApplied) {
      _pendingApplied = true;
      final pending = ref.read(pendingN3SlidesProvider);
      if (pending != null && pending.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(instagramPostProvider.notifier).setSlides(pending);
          ref.read(pendingN3SlidesProvider.notifier).state = null;
        });
      }
    }
  }

  void _generate() {
    final msg = _briefingCtrl.text.trim();
    if (msg.isEmpty) return;
    _appliedOutput = null;
    _savedToHistory = false;

    final layout = ref.read(instagramPostProvider).defaultLayout;
    final extraCtx = layout == SlideLayout.imageCover
        ? '''

---
TIPO DE LAYOUT SELECIONADO: Tipo 2 — Image Cover (imagem de fundo full-bleed)
Adapte os slides para este formato:
- "headline": título curto e impactante (máximo 7 palavras) — aparece em card sobre a imagem
- "body": subtítulo breve e opcional (máximo 20 palavras, pode ser string vazia "")
- "swipeText": texto de swipe opcional em português (ex: "Arraste para o lado →", ou "" para omitir)
O JSON de cada slide deve ter os três campos: headline, body, swipeText.'''
        : null;

    ref.read(generationProvider.notifier).generate(
          flowSlug: _flowSlug,
          userMessage: extraCtx != null ? msg + extraCtx : msg,
        );
  }

  void _reset() {
    ref.read(generationProvider.notifier).clear();
    ref.read(instagramPostProvider.notifier).setSlides(const []);
    setState(() {
      _current = 0;
      _appliedOutput = null;
      _savedToHistory = false;
    });
  }

  Future<void> _exportCurrent() async {
    setState(() => _exporting = true);
    try {
      final bytes = await capturePng(_boundaryKey);
      if (bytes != null) {
        downloadPng(bytes, 'instagram-slide-${_current + 1}.png');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportAll(int total) async {
    setState(() => _exporting = true);
    try {
      for (var i = 0; i < total; i++) {
        setState(() => _current = i);
        // espera o frame renderizar o slide i antes de capturar
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        final bytes = await capturePng(_boundaryKey);
        if (bytes != null) {
          downloadPng(bytes, 'instagram-slide-${i + 1}.png');
        }
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickAvatar() async {
    final bytes = await pickImageBytes();
    if (bytes != null) {
      ref.read(instagramPostProvider.notifier).setAvatar(bytes);
    }
  }

  Future<void> _openPublishDialog() async {
    var connection = ref.read(instagramConnectionProvider).valueOrNull;
    // Reconecta também quando o status já é "active" mas o ig_username ainda
    // não foi resolvido (conexões criadas antes da identidade ser sincronizada).
    final needsConnect = connection?.status != InstagramConnectionStatus.active ||
        connection?.igUsername == null;
    if (needsConnect) {
      await _connectInstagram();
      connection = ref.read(instagramConnectionProvider).valueOrNull;
      if (connection?.status != InstagramConnectionStatus.active ||
          connection?.igUsername == null) {
        return;
      }
    }

    final style = ref.read(instagramPostProvider);
    final totalSlides = style.slides.length;
    final previousSlide = _current;

    final imagesBytes = <Uint8List>[];
    setState(() => _exporting = true);
    try {
      for (var i = 0; i < totalSlides; i++) {
        setState(() => _current = i);
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        final bytes = await capturePng(_boundaryKey);
        if (bytes != null) imagesBytes.add(bytes);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
    setState(() => _current = previousSlide);

    if (imagesBytes.isEmpty || !mounted) return;

    final slide = style.slides[previousSlide];
    final defaultCaption = [slide.headline, slide.body]
        .where((s) => s.trim().isNotEmpty)
        .join('\n\n');

    await showDialog<void>(
      context: context,
      builder: (_) =>
          _PublishDialog(imagesBytes: imagesBytes, defaultCaption: defaultCaption),
    );
  }

  Future<void> _connectInstagram() async {
    try {
      final repo = ref.read(instagramConnectionRepositoryProvider);
      final url = await repo.startConnect();

      if (url == null) {
        // Já existe uma conexão ativa — só sincroniza o estado local.
        ref.invalidate(instagramConnectionProvider);
        await ref.read(instagramConnectionProvider.future);
        return;
      }

      web.window.open(url, '_blank');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Autorize sua conta no Instagram na aba aberta e depois volte aqui.'),
          duration: Duration(seconds: 5),
        ),
      );

      // Tenta sincronizar o status algumas vezes após a autorização.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        final status = await repo.checkStatus();
        ref.invalidate(instagramConnectionProvider);
        if (status == InstagramConnectionStatus.active) break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao conectar Instagram: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final gen = ref.watch(generationProvider);
    final style = ref.watch(instagramPostProvider);

    // Restaura estilo salvo pelo usuário na primeira renderização.
    if (!_styleLoaded) {
      _styleLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final saved = await loadStyleFromPrefs();
        if (saved != null && mounted) {
          ref.read(instagramPostProvider.notifier).restoreStyleOnly(saved);
        }
      });
    }

    // Em debug: restaura o último histórico automaticamente ao abrir a página.
    if (false && kDebugMode && !_debugRestored && !style.hasSlides) {
      final history = ref.watch(igPostHistoryProvider).valueOrNull;
      if (history != null && history.isNotEmpty) {
        _debugRestored = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final entry = history.first;
          ref.read(instagramPostProvider.notifier).restoreFromHistory(
                entry.toPostStyle(),
                entry.slides,
              );
        });
      }
    }

    // Quando a geração concluir, parseia os slides e salva no histórico.
    if (gen.status == GenerationStatus.done &&
        gen.hasOutput &&
        gen.output != _appliedOutput) {
      _appliedOutput = gen.output;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final layout = ref.read(instagramPostProvider).defaultLayout;
        final slides = parseSlides(gen.output, defaultLayout: layout);
        ref.read(instagramPostProvider.notifier).setSlides(slides);
        setState(() => _current = 0);
        if (!_savedToHistory && slides.isNotEmpty) {
          _savedToHistory = true;
          ref.read(igPostHistoryProvider.notifier).add(
                briefing: _briefingCtrl.text.trim(),
                slides: slides,
                style: ref.read(instagramPostProvider),
              );
        }
      });
    }

    if (_current >= style.slides.length && style.slides.isNotEmpty) {
      _current = style.slides.length - 1;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 900;
        final controls = _ControlsColumn(
          briefingCtrl: _briefingCtrl,
          gen: gen,
          style: style,
          currentIndex: _current,
          onGenerate: _generate,
          onReset: _reset,
          onPickAvatar: _pickAvatar,
          onSelectSlide: (i) => setState(() => _current = i),
        );
        final preview = _PreviewColumn(
          style: style,
          current: _current,
          boundaryKey: _boundaryKey,
          exporting: _exporting,
          onPrev: _current > 0 ? () => setState(() => _current--) : null,
          onNext: _current < style.slides.length - 1
              ? () => setState(() => _current++)
              : null,
          onExportCurrent: _exporting ? null : _exportCurrent,
          onExportAll:
              _exporting ? null : () => _exportAll(style.slides.length),
          onPublish: _exporting ? null : _openPublishDialog,
        );

        // Header e descrição — fixos no topo
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Instagram Text Post',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (_lastAutoSave != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 11,
                            color: onSurface.withValues(alpha: 0.3)),
                        const SizedBox(width: 3),
                        Text(
                          'Salvo ${_lastAutoSave!.hour.toString().padLeft(2, '0')}:${_lastAutoSave!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: 11,
                              color: onSurface.withValues(alpha: 0.3)),
                        ),
                      ],
                    ),
                  ),
                Consumer(builder: (_, ref, __) {
                  final count =
                      ref.watch(igPostHistoryProvider).valueOrNull?.length ?? 0;
                  return TextButton.icon(
                    onPressed: () => showIgPostHistoryPanel(context),
                    icon: const Icon(Icons.history, size: 14),
                    label: Text(
                      count > 0 ? 'Histórico ($count)' : 'Histórico',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: onSurface.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A IA gera o texto do carrossel; o layout é montado por código e exportado em PNG.',
              style: TextStyle(
                fontSize: 14,
                color: onSurface.withValues(alpha: 0.45),
                height: 1.6,
              ),
            ),
          ],
        );

        if (wide) {
          // Wide: header fixo, controles rolam, preview acompanha a tela
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: header,
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 0, 16, 32),
                        child: controls,
                      ),
                    ),
                    SizedBox(
                      width: 412,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(0, 0, 32, 32),
                        child: preview,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // Narrow: tudo em scroll único
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 28),
              preview,
              const SizedBox(height: 28),
              controls,
            ],
          ),
        );
      },
    );
  }
}

// ─── Coluna de preview ────────────────────────────────────────────────────────

class _PreviewColumn extends ConsumerWidget {
  final PostStyle style;
  final int current;
  final GlobalKey boundaryKey;
  final bool exporting;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onExportCurrent;
  final VoidCallback? onExportAll;
  final VoidCallback? onPublish;

  const _PreviewColumn({
    required this.style,
    required this.current,
    required this.boundaryKey,
    required this.exporting,
    required this.onPrev,
    required this.onNext,
    required this.onExportCurrent,
    required this.onExportAll,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    if (!style.hasSlides) {
      return Container(
        height: 480,
        decoration: BoxDecoration(
          color: onSurface.withValues(alpha: 0.02),
          border: Border.all(color: outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_outlined,
                  size: 32, color: onSurface.withValues(alpha: 0.15)),
              const SizedBox(height: 10),
              Text(
                'O preview aparece após gerar o conteúdo.',
                style: TextStyle(
                  fontSize: 13,
                  color: onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final slide = style.slides[current];
    final total = style.slides.length;

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Canvas renderizado no tamanho lógico (432x540), escalado para caber
          // na largura disponível. O RepaintBoundary mantém o tamanho lógico,
          // então o export sai sempre em ~1080x1350.
          LayoutBuilder(
            builder: (context, c) {
              final displayW =
                  c.maxWidth.clamp(0.0, kCanvasWidth).toDouble();
              final displayH = displayW * (kCanvasHeight / kCanvasWidth);
              return Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: displayW,
                    height: displayH,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: kCanvasWidth,
                        height: kCanvasHeight,
                        child: slide.isType2
                            ? PostCanvasType2(
                                style: style,
                                slide: slide,
                                index: current,
                                total: total,
                                boundaryKey: boundaryKey,
                              )
                            : slide.isType3
                                ? PostCanvasType3(
                                    style: style,
                                    slide: slide,
                                    index: current,
                                    total: total,
                                    boundaryKey: boundaryKey,
                                  )
                                : slide.isType4
                                    ? PostCanvasType4(
                                        style: style,
                                        slide: slide,
                                        index: current,
                                        total: total,
                                        boundaryKey: boundaryKey,
                                      )
                                    : PostCanvas(
                                        style: style,
                                        slide: slide,
                                        index: current,
                                        total: total,
                                        boundaryKey: boundaryKey,
                                      ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          // Navegação
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                color: onSurface.withValues(alpha: 0.6),
              ),
              Text(
                '${current + 1} / $total',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.5),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onExportCurrent,
                  icon: const Icon(Icons.download_outlined, size: 15),
                  label: const Text('Exportar slide',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.7),
                    side: BorderSide(color: outline.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExportAll,
                  icon: exporting
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white),
                        )
                      : const Icon(Icons.download_done_outlined, size: 15),
                  label: Text(exporting ? 'Exportando...' : 'Exportar tudo',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Consumer(builder: (_, ref, __) {
            final connection = ref.watch(instagramConnectionProvider).valueOrNull;
            final active = connection?.status == InstagramConnectionStatus.active;
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPublish,
                icon: const Icon(Icons.send_outlined, size: 15),
                label: Text(
                  active
                      ? 'Publicar no Instagram (@${connection?.igUsername ?? ''})'
                      : 'Conectar e publicar no Instagram',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: onSurface.withValues(alpha: 0.8),
                  side: BorderSide(color: outline.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Coluna de controles ──────────────────────────────────────────────────────

class _ControlsColumn extends ConsumerWidget {
  final TextEditingController briefingCtrl;
  final GenerationState gen;
  final PostStyle style;
  final int currentIndex;
  final VoidCallback onGenerate;
  final VoidCallback onReset;
  final VoidCallback onPickAvatar;
  final ValueChanged<int> onSelectSlide;

  const _ControlsColumn({
    required this.briefingCtrl,
    required this.gen,
    required this.style,
    required this.currentIndex,
    required this.onGenerate,
    required this.onReset,
    required this.onPickAvatar,
    required this.onSelectSlide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(instagramPostProvider.notifier);
    final generating = gen.isGenerating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Geração: card completo sem slides, barra compacta com slides ──
        if (!style.hasSlides) ...[
          _Card(
            title: 'Conteúdo (IA)',
            icon: Icons.auto_awesome,
            trailing: generating
                ? null
                : _TextBtn(
                    label: 'Salvar',
                    icon: Icons.bookmark_outline,
                    onTap: () async {
                      await saveStyleToPrefs(style);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configurações salvas!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LayoutTypeSelector(
                  selected: style.defaultLayout,
                  onSelect: notifier.setDefaultLayout,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: briefingCtrl,
                  minLines: 3,
                  maxLines: 8,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                  decoration: _input(context,
                      'Ex: carrossel sobre os 3 erros que travam a operação de uma PME...'),
                ),
                const SizedBox(height: 12),
                if (generating)
                  _StatusLine(gen: gen)
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: onGenerate,
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Gerar conteúdo',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                if (gen.status == GenerationStatus.error && gen.error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    gen.error!,
                    style: TextStyle(
                        fontSize: 12, color: Colors.red.withValues(alpha: 0.8)),
                  ),
                ],
              ],
            ),
          ),
          // Destaque visível antes de gerar
          const SizedBox(height: 16),
          _Card(
            title: 'Destaque  [hl]',
            icon: Icons.highlight,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _swatchRow(context, label: 'Cor padrão',
                  selected: style.highlightColor,
                  swatches: kHighlightSwatches,
                  onSelect: notifier.setHighlightColor),
              const SizedBox(height: 12),
              _MarkupHint(),
            ]),
          ),
        ] else ...[
          // Barra compacta pós-geração
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.add_circle_outline, size: 15),
                  label: const Text('Novo carrossel',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TextBtn(
                label: 'Salvar conf.',
                icon: Icons.bookmark_outline,
                onTap: () async {
                  await saveStyleToPrefs(style);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Configurações salvas!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],

        if (style.hasSlides) ...[
          const SizedBox(height: 16),
          // ── Editor de texto do slide ─────────────────────────────────────
          _Card(
            title: 'Texto dos slides',
            icon: Icons.edit_note_outlined,
            child: _SlideEditor(
              slides: style.slides,
              currentIndex: currentIndex,
              onSelectSlide: onSelectSlide,
              onHeadline: (v) =>
                  notifier.updateSlide(currentIndex, headline: v),
              onBody: (v) => notifier.updateSlide(currentIndex, body: v),
              onPickImage: () async {
                final bytes = await pickImageBytes();
                if (bytes != null) notifier.setSlideImage(currentIndex, bytes);
              },
              onClearImage: () => notifier.setSlideImage(currentIndex, null),
              onImageAbove: (v) =>
                  notifier.setSlideImageAbove(currentIndex, v),
              onShowHeader: (v) =>
                  notifier.setSlideShowHeader(currentIndex, v),
              onShowCounter: (v) =>
                  notifier.setSlideShowCounter(currentIndex, v),
              onLayout: (v) => notifier.setSlideLayout(currentIndex, v),
              onPickCoverImage: () async {
                final bytes = await pickImageBytes();
                if (bytes != null) {
                  notifier.setSlideCoverImage(currentIndex, bytes);
                }
              },
              onClearCoverImage: () =>
                  notifier.setSlideCoverImage(currentIndex, null),
              onCoverVariant: (v) =>
                  notifier.setSlideCoverVariant(currentIndex, v),
              onSwipeText: (v) =>
                  notifier.setSlideSwipeText(currentIndex, v),
              onGridText: (blockIdx, v) =>
                  notifier.setGridText(currentIndex, blockIdx, v),
              onGridBold: (blockIdx, v) =>
                  notifier.setGridBold(currentIndex, blockIdx, v),
              onGridSpacing: (v) =>
                  notifier.setGridSpacing(currentIndex, v),
              onTextAlign: (v) =>
                  notifier.setSlideTextAlign(currentIndex, v),
              onSlideBgColor: (c) =>
                  notifier.setSlideBgColor(currentIndex, c),
              onSlideTextColor: (c) =>
                  notifier.setSlideTextColor(currentIndex, c),
              onSlideHeadlineColor: (c) =>
                  notifier.setSlideHeadlineColor(currentIndex, c),
              onSlideBodyColor: (c) =>
                  notifier.setSlideBodyColor(currentIndex, c),
              onSwipeTextColor: (c) =>
                  notifier.setSlideSwipeTextColor(currentIndex, c),
              onClearSlideColors: () =>
                  notifier.clearSlideColors(currentIndex),
            ),
          ),

          // ── Cards contextuais: Tipo 1 vs Tipo 2 ──────────────────────
          ..._globalCards(context, notifier, style, currentIndex),
        ],
      ],
    );
  }

  // Retorna os cards globais corretos para o tipo do slide atual.
  List<Widget> _globalCards(
    BuildContext context,
    InstagramPostNotifier notifier,
    PostStyle style,
    int currentIndex,
  ) {
    final isType2 = style.slides.isNotEmpty &&
        style.slides[currentIndex].isType2;
    final isType3 = style.slides.isNotEmpty &&
        style.slides[currentIndex].isType3;
    final isType4 = style.slides.isNotEmpty &&
        style.slides[currentIndex].isType4;

    // ── Headline e body (comuns aos dois tipos) ────────────────────────
    final headlineCard = _Card(
      title: 'Headline',
      icon: Icons.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Toggle(label: 'Negrito', icon: Icons.format_bold,
              active: style.bold, onTap: notifier.toggleBold),
          _Toggle(label: 'Itálico', icon: Icons.format_italic,
              active: style.italic, onTap: notifier.toggleItalic),
          _Toggle(label: 'Sublinhado', icon: Icons.format_underlined,
              active: style.underline, onTap: notifier.toggleUnderline),
        ]),
        const SizedBox(height: 12),
        _StepCounter(label: 'Tamanho', value: style.bodyFontSize,
            min: 20, max: 44, onChanged: notifier.setBodyFontSize),
      ]),
    );

    final bodyCard = _Card(
      title: 'Texto de apoio',
      icon: Icons.format_size,
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        _Toggle(label: 'Negrito', icon: Icons.format_bold,
            active: style.bodyBold, onTap: notifier.toggleBodyBold),
        _Toggle(label: 'Itálico', icon: Icons.format_italic,
            active: style.bodyItalic, onTap: notifier.toggleBodyItalic),
        _Toggle(label: 'Sublinhado', icon: Icons.format_underlined,
            active: style.bodyUnderline, onTap: notifier.toggleBodyUnderline),
      ]),
    );

    final extrasCard = _Card(
      title: 'Extras',
      icon: Icons.tune,
      child: _Toggle(label: 'Setas de navegação', icon: Icons.arrow_forward,
          active: style.showArrows, onTap: notifier.toggleArrows),
    );

    if (isType3 || isType4) {
      // ── Cards compartilhados Tipo 3 e 4 ──────────────────────────────
      return [
        const SizedBox(height: 16),
        headlineCard,
        const SizedBox(height: 16),
        bodyCard,
        const SizedBox(height: 16),
        _Card(
          title: 'Fontes',
          icon: Icons.text_fields_outlined,
          child: Column(children: [
            _FontDropdown(label: 'Conteúdo', value: style.bodyFont,
                onChanged: notifier.setBodyFont),
            _FontDropdown(label: 'Contagem (1/N)', value: style.counterFont,
                onChanged: notifier.setCounterFont),
          ]),
        ),
        const SizedBox(height: 16),
        _Card(
          title: 'Cores',
          icon: Icons.color_lens_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _swatchRow(context, label: 'Fundo',
                selected: style.bgColor, onSelect: notifier.setBgColor),
            const SizedBox(height: 12),
            _ColorRow(label: 'Headline',
                selected: style.resolvedHeadlineColor(),
                isOverride: style.headlineColor != null,
                onSelect: notifier.setHeadlineColor,
                onReset: notifier.resetHeadlineColor),
            const SizedBox(height: 12),
            _ColorRow(label: 'Texto de apoio',
                selected: style.resolvedBodyColor(),
                isOverride: style.bodyColor != null,
                onSelect: notifier.setBodyColor,
                onReset: notifier.resetBodyColor),
          ]),
        ),
        const SizedBox(height: 16),
        extrasCard,
      ];
    }

    if (isType2) {
      // ── Cards Tipo 2 ─────────────────────────────────────────────────
      return [
        const SizedBox(height: 16),
        // Logo
        _Card(
          title: 'Logo',
          icon: Icons.image_outlined,
          child: _LogoPickerRow(
            logoBytes: style.logoBytes,
            onPick: () async {
              final bytes = await pickImageBytes(allowSvg: true);
              if (bytes != null) notifier.setLogo(bytes);
            },
            onClear: () => notifier.setLogo(null),
          ),
        ),
        const SizedBox(height: 16),
        headlineCard,
        const SizedBox(height: 16),
        bodyCard,
        const SizedBox(height: 16),
        // Fonte do conteúdo (só bodyFont + counterFont)
        _Card(
          title: 'Fontes',
          icon: Icons.text_fields_outlined,
          child: Column(children: [
            _FontDropdown(label: 'Conteúdo', value: style.bodyFont,
                onChanged: notifier.setBodyFont),
            _FontDropdown(label: 'Contagem (1/N)', value: style.counterFont,
                onChanged: notifier.setCounterFont),
          ]),
        ),
        const SizedBox(height: 16),
        // Cores: fundo dos cards + headline + body
        _Card(
          title: 'Cores',
          icon: Icons.color_lens_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _swatchRow(context, label: 'Fundo dos cards',
                selected: style.bgColor, onSelect: notifier.setBgColor),
            const SizedBox(height: 12),
            _ColorRow(label: 'Headline',
                selected: style.resolvedHeadlineColor(),
                isOverride: style.headlineColor != null,
                onSelect: notifier.setHeadlineColor,
                onReset: notifier.resetHeadlineColor),
            const SizedBox(height: 12),
            _ColorRow(label: 'Texto de apoio',
                selected: style.resolvedBodyColor(),
                isOverride: style.bodyColor != null,
                onSelect: notifier.setBodyColor,
                onReset: notifier.resetBodyColor),
          ]),
        ),
        const SizedBox(height: 16),
        extrasCard,
      ];
    }

    // ── Cards Tipo 1 ─────────────────────────────────────────────────────
    return [
      const SizedBox(height: 16),
      _Card(
        title: 'Estilo do criador',
        icon: Icons.palette_outlined,
        child: Wrap(spacing: 8, runSpacing: 8,
            children: kCreatorPresets
                .map((p) => _PresetChip(preset: p, onTap: () => notifier.applyPreset(p)))
                .toList()),
      ),
      const SizedBox(height: 16),
      _Card(
        title: 'Perfil',
        icon: Icons.account_circle_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            GestureDetector(
              onTap: onPickAvatar,
              child: CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: style.avatarBytes != null
                    ? MemoryImage(style.avatarBytes!)
                    : null,
                child: style.avatarBytes == null
                    ? const Icon(Icons.add_a_photo_outlined, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(children: [
              _MiniField(label: 'Nome', value: style.profileName,
                  onChanged: notifier.setProfileName),
              const SizedBox(height: 8),
              _MiniField(label: '@', value: style.handle,
                  onChanged: notifier.setHandle),
            ])),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Toggle(label: 'Verificado', icon: Icons.verified,
                active: style.showVerifiedBadge, onTap: notifier.toggleVerifiedBadge),
            _Toggle(label: 'Centralizar conteúdo', icon: Icons.vertical_align_center,
                active: style.centerContent, onTap: notifier.toggleCenterContent),
          ]),
          const SizedBox(height: 12),
          _LogoPickerRow(
            logoBytes: style.logoBytes,
            onPick: () async {
              final bytes = await pickImageBytes(allowSvg: true);
              if (bytes != null) notifier.setLogo(bytes);
            },
            onClear: () => notifier.setLogo(null),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _Card(
        title: 'Fontes',
        icon: Icons.text_fields_outlined,
        child: Column(children: [
          _FontDropdown(label: 'Nome', value: style.nameFont,
              onChanged: notifier.setNameFont),
          _FontDropdown(label: '@ do perfil', value: style.handleFont,
              onChanged: notifier.setHandleFont),
          _FontDropdown(label: 'Conteúdo', value: style.bodyFont,
              onChanged: notifier.setBodyFont),
          _FontDropdown(label: 'Contagem (1/N)', value: style.counterFont,
              onChanged: notifier.setCounterFont),
        ]),
      ),
      const SizedBox(height: 16),
      headlineCard,
      const SizedBox(height: 16),
      bodyCard,
      const SizedBox(height: 16),
      extrasCard,
      const SizedBox(height: 16),
      _Card(
        title: 'Cores Geral',
        icon: Icons.color_lens_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _swatchRow(context, label: 'Fundo', selected: style.bgColor,
              onSelect: notifier.setBgColor),
          const SizedBox(height: 12),
          _ColorRow(label: 'Headline',
              selected: style.resolvedHeadlineColor(),
              isOverride: style.headlineColor != null,
              onSelect: notifier.setHeadlineColor,
              onReset: notifier.resetHeadlineColor),
          const SizedBox(height: 12),
          _ColorRow(label: 'Texto de apoio',
              selected: style.resolvedBodyColor(),
              isOverride: style.bodyColor != null,
              onSelect: notifier.setBodyColor,
              onReset: notifier.resetBodyColor),
        ]),
      ),
    ];
  }

  Widget _swatchRow(
    BuildContext context, {
    required String label,
    required Color selected,
    List<Color>? swatches,
    required ValueChanged<Color> onSelect,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (swatches ?? kBackgroundSwatches).map((c) {
            final isSel = c.toARGB32() == selected.toARGB32();
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSel
                        ? Theme.of(context).colorScheme.primary
                        : onSurface.withValues(alpha: 0.2),
                    width: isSel ? 2.5 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── _ColorRow: swatch de texto com botão de reset ───────────────────────────

class _ColorRow extends StatelessWidget {
  final String label;
  final Color selected;
  final bool isOverride;
  final ValueChanged<Color> onSelect;
  final VoidCallback onReset;

  const _ColorRow({
    required this.label,
    required this.selected,
    required this.isOverride,
    required this.onSelect,
    required this.onReset,
  });


  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
            if (isOverride) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onReset,
                child: Text(
                  'resetar',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.7),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kBackgroundSwatches.map((c) {
            final isSel = c.toARGB32() == selected.toARGB32();
            return GestureDetector(
              onTap: () => onSelect(c),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSel
                        ? Theme.of(context).colorScheme.primary
                        : onSurface.withValues(alpha: 0.2),
                    width: isSel ? 2.5 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Sub-widgets de controle ──────────────────────────────────────────────────

class _SlideEditor extends StatelessWidget {
  final List<SlideContent> slides;
  final int currentIndex;
  final ValueChanged<int> onSelectSlide;
  final ValueChanged<String> onHeadline;
  final ValueChanged<String> onBody;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final ValueChanged<bool> onImageAbove;
  final ValueChanged<bool> onShowHeader;
  final ValueChanged<bool> onShowCounter;
  final ValueChanged<SlideLayout> onLayout;
  final VoidCallback onPickCoverImage;
  final VoidCallback onClearCoverImage;
  final ValueChanged<ImageCoverVariant> onCoverVariant;
  final ValueChanged<String> onSwipeText;
  final void Function(int blockIdx, String text) onGridText;
  final void Function(int blockIdx, bool bold) onGridBold;
  final ValueChanged<double> onGridSpacing;
  final ValueChanged<TextAlign> onTextAlign;
  final ValueChanged<Color?> onSlideBgColor;
  final ValueChanged<Color?> onSlideTextColor;
  final ValueChanged<Color?> onSlideHeadlineColor;
  final ValueChanged<Color?> onSlideBodyColor;
  final ValueChanged<Color?> onSwipeTextColor;
  final VoidCallback onClearSlideColors;

  const _SlideEditor({
    required this.slides,
    required this.currentIndex,
    required this.onSelectSlide,
    required this.onHeadline,
    required this.onBody,
    required this.onPickImage,
    required this.onClearImage,
    required this.onImageAbove,
    required this.onShowHeader,
    required this.onShowCounter,
    required this.onLayout,
    required this.onPickCoverImage,
    required this.onClearCoverImage,
    required this.onCoverVariant,
    required this.onSwipeText,
    required this.onGridText,
    required this.onGridBold,
    required this.onGridSpacing,
    required this.onTextAlign,
    required this.onSlideBgColor,
    required this.onSlideTextColor,
    required this.onSlideHeadlineColor,
    required this.onSlideBodyColor,
    required this.onSwipeTextColor,
    required this.onClearSlideColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;
    final slide = slides[currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seletor de slide
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(slides.length, (i) {
              final sel = i == currentIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
                  selected: sel,
                  onSelected: (_) => onSelectSlide(i),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // Tipos 3 e 4 têm seus próprios campos de texto — não duplicar aqui
        if (!slide.isType3 && !slide.isType4) ...[
          // chave por índice para recriar com o conteúdo correto ao trocar de slide
          _MiniField(
            key: ValueKey('headline-$currentIndex'),
            label: 'Headline',
            value: slide.headline,
            maxLines: 3,
            onChanged: onHeadline,
          ),
          const SizedBox(height: 8),
          _MiniField(
            key: ValueKey('body-$currentIndex'),
            label: 'Texto de apoio',
            value: slide.body,
            maxLines: 5,
            onChanged: onBody,
          ),
          const SizedBox(height: 6),
          _MarkupHintInline(),
          const SizedBox(height: 14),
          Divider(color: outline.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),
        ] else ...[
          const SizedBox(height: 8),
          Divider(color: outline.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),
        ],

        // ── Opções exclusivas do Tipo 1 ──────────────────────────────
        if (!slide.isType2 && !slide.isType3 && !slide.isType4) ...[
          // Mostrar perfil
          Row(
            children: [
              Expanded(
                child: Text('Mostrar perfil neste slide',
                    style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.7))),
              ),
              Switch(
                value: slide.showHeader,
                onChanged: onShowHeader,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Imagem do slide
          Row(
            children: [
              Expanded(
                child: Text('Imagem do slide',
                    style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.7))),
              ),
              if (slide.imageBytes != null)
                TextButton(
                  onPressed: onClearImage,
                  style: TextButton.styleFrom(
                    foregroundColor: onSurface.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Remover', style: TextStyle(fontSize: 11)),
                ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: onPickImage,
                icon: Icon(
                  slide.imageBytes != null ? Icons.swap_horiz : Icons.add_photo_alternate_outlined,
                  size: 14,
                ),
                label: Text(slide.imageBytes != null ? 'Trocar' : 'Adicionar',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          if (slide.imageBytes != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Posição:',
                    style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
                const SizedBox(width: 10),
                _PosChip(label: 'Acima', icon: Icons.vertical_align_top,
                    active: slide.imageAbove, onTap: () => onImageAbove(true)),
                const SizedBox(width: 8),
                _PosChip(label: 'Abaixo', icon: Icons.vertical_align_bottom,
                    active: !slide.imageAbove, onTap: () => onImageAbove(false)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(slide.imageBytes!, height: 80,
                  width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ],

        // ── Opções exclusivas dos Tipos 2, 3 e 4 ─────────────────────
        if (slide.isType2 || slide.isType3 || slide.isType4) ...[
          Row(
            children: [
              Expanded(
                child: Text('Exibir contador neste slide',
                    style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.7))),
              ),
              Switch(
                value: slide.showCounter,
                onChanged: onShowCounter,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 14),
        Divider(color: outline.withValues(alpha: 0.3), height: 1),
        const SizedBox(height: 14),

        // ── Tipo do layout ────────────────────────────────────────────
        Text('Layout:',
            style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.65))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _PosChip(
              label: 'Tipo 1 — texto',
              icon: Icons.text_fields,
              active: !slide.isType2 && !slide.isType3 && !slide.isType4,
              onTap: () => onLayout(SlideLayout.textPost),
            ),
            _PosChip(
              label: 'Tipo 2 — capa',
              icon: Icons.image_outlined,
              active: slide.isType2,
              onTap: () => onLayout(SlideLayout.imageCover),
            ),
            _PosChip(
              label: 'Tipo 3 — grade',
              icon: Icons.grid_view_outlined,
              active: slide.isType3,
              onTap: () => onLayout(SlideLayout.textGrid),
            ),
            _PosChip(
              label: 'Tipo 4 — pilha',
              icon: Icons.view_agenda_outlined,
              active: slide.isType4,
              onTap: () => onLayout(SlideLayout.imageStack),
            ),
          ],
        ),

        // ── Controles exclusivos do Tipo 2 ────────────────────────────
        if (slide.isType2) ...[
          const SizedBox(height: 12),

          // Imagem de capa — primeiro e mais importante no Tipo 2
          _CoverImagePicker(
            coverImageBytes: slide.coverImageBytes,
            onPick: onPickCoverImage,
            onClear: onClearCoverImage,
          ),

          const SizedBox(height: 12),
          // Variante
          Text('Variante do layout:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _PosChip(
                label: 'Logo + título em card',
                icon: Icons.location_on_outlined,
                active: slide.coverVariant == ImageCoverVariant.logoMid,
                onTap: () => onCoverVariant(ImageCoverVariant.logoMid),
              ),
              _PosChip(
                label: 'Logo topo + cards',
                icon: Icons.vertical_align_top,
                active: slide.coverVariant == ImageCoverVariant.logoTop,
                onTap: () => onCoverVariant(ImageCoverVariant.logoTop),
              ),
              _PosChip(
                label: 'Subtítulo antes',
                icon: Icons.swap_vert,
                active: slide.coverVariant == ImageCoverVariant.subtitleTop,
                onTap: () => onCoverVariant(ImageCoverVariant.subtitleTop),
              ),
              _PosChip(
                label: 'Texto sobre imagem',
                icon: Icons.format_color_text_outlined,
                active: slide.coverVariant == ImageCoverVariant.logoTopInline,
                onTap: () => onCoverVariant(ImageCoverVariant.logoTopInline),
              ),
            ],
          ),

          const SizedBox(height: 12),
          // Swipe hint
          _MiniField(
            key: ValueKey('swipe-$currentIndex'),
            label: 'Texto de swipe (opcional)',
            value: slide.swipeText,
            maxLines: 1,
            onChanged: onSwipeText,
          ),
        ],

        // ── Controles exclusivos do Tipo 3 ────────────────────────────
        if (slide.isType3) ...[
          const SizedBox(height: 14),
          _AlignSelector(selected: slide.textAlign, onSelect: onTextAlign),
          const SizedBox(height: 14),
          _StepCounter(
            label: 'Espaço entre linhas (×)',
            value: slide.gridSpacing,
            min: 1.0,
            max: 4.0,
            step: 0.1,
            decimals: 1,
            onChanged: onGridSpacing,
          ),
          const SizedBox(height: 16),
          _CoverImagePicker(
            coverImageBytes: slide.coverImageBytes,
            onPick: onPickCoverImage,
            onClear: onClearCoverImage,
          ),
          const SizedBox(height: 16),
          ..._gridBlockField(context, 0, 'Topo esquerdo', slide, onGridText, onGridBold),
          const SizedBox(height: 10),
          ..._gridBlockField(context, 1, 'Topo direito', slide, onGridText, onGridBold),
          const SizedBox(height: 10),
          ..._gridBlockField(context, 2, 'Base esquerdo', slide, onGridText, onGridBold),
          const SizedBox(height: 10),
          ..._gridBlockField(context, 3, 'Base direito', slide, onGridText, onGridBold),
          const SizedBox(height: 6),
          _MarkupHintInline(),
        ],

        // ── Controles exclusivos do Tipo 4 ────────────────────────────
        if (slide.isType4) ...[
          const SizedBox(height: 14),
          _AlignSelector(
            selected: slide.textAlign,
            onSelect: onTextAlign,
          ),
          const SizedBox(height: 12),
          Text('Imagem 1:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          _CoverImagePicker(
            coverImageBytes: slide.imageBytes,
            onPick: onPickImage,
            onClear: onClearImage,
          ),
          const SizedBox(height: 10),
          _MiniField(
            key: ValueKey('headline-type4-$currentIndex'),
            label: 'Texto do card 1 (opcional)',
            value: slide.headline,
            maxLines: 3,
            onChanged: onHeadline,
          ),
          const SizedBox(height: 14),
          Text('Imagem 2:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          _CoverImagePicker(
            coverImageBytes: slide.coverImageBytes,
            onPick: onPickCoverImage,
            onClear: onClearCoverImage,
          ),
          const SizedBox(height: 10),
          _MiniField(
            key: ValueKey('body-type4-$currentIndex'),
            label: 'Texto do card 2 (opcional)',
            value: slide.body,
            maxLines: 3,
            onChanged: onBody,
          ),
          const SizedBox(height: 6),
          _MarkupHintInline(),
        ],

        // ── Cores do slide (sobrescrevem as globais) ───────────────────
        const SizedBox(height: 14),
        Divider(color: outline.withValues(alpha: 0.3), height: 1),
        const SizedBox(height: 14),
        _SlideColorSection(
          slide: slide,
          onBgColor: onSlideBgColor,
          onTextColor: onSlideTextColor,
          onHeadlineColor: onSlideHeadlineColor,
          onBodyColor: onSlideBodyColor,
          onSwipeColor: onSwipeTextColor,
          onClear: onClearSlideColors,
        ),
      ],
    );
  }

  List<Widget> _gridBlockField(
    BuildContext context,
    int idx,
    String label,
    SlideContent slide,
    void Function(int, String) onText,
    void Function(int, bool) onBold,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    final isBold = idx < slide.gridBolds.length && slide.gridBolds[idx];
    return [
      Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const Spacer(),
          GestureDetector(
            onTap: () => onBold(idx, !isBold),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isBold ? primary.withValues(alpha: 0.12) : Colors.transparent,
                border: Border.all(
                  color: isBold
                      ? primary.withValues(alpha: 0.45)
                      : onSurface.withValues(alpha: 0.18),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_bold, size: 13,
                      color: isBold ? primary : onSurface.withValues(alpha: 0.45)),
                  const SizedBox(width: 3),
                  Text('Negrito',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                        color: isBold ? primary : onSurface.withValues(alpha: 0.5),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      _MiniField(
        key: ValueKey('g$idx-$currentIndex'),
        label: 'Texto (opcional)',
        value: idx < slide.gridTexts.length ? slide.gridTexts[idx] : '',
        maxLines: 4,
        onChanged: (v) => onText(idx, v),
      ),
    ];
  }
}

class _FontDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const _FontDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              isDense: true,
              style: TextStyle(fontSize: 12, color: onSurface),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              items: kAvailableFonts
                  .map((f) =>
                      DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _Toggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _Toggle({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.14) : Colors.transparent,
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.5)
                : onSurface.withValues(alpha: 0.18),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active ? primary : onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? primary : onSurface.withValues(alpha: 0.55),
                )),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final CreatorPreset preset;
  final VoidCallback onTap;

  const _PresetChip({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: onSurface.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: preset.bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: onSurface.withValues(alpha: 0.2)),
              ),
            ),
            const SizedBox(width: 7),
            Text(preset.name, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _MiniField extends StatefulWidget {
  final String label;
  final String value;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _MiniField({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 1,
    required this.onChanged,
  });

  @override
  State<_MiniField> createState() => _MiniFieldState();
}

class _MiniFieldState extends State<_MiniField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      minLines: 1,
      maxLines: widget.maxLines,
      style: const TextStyle(fontSize: 12, height: 1.4),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle:
            TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.5)),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final GenerationState gen;
  const _StatusLine({required this.gen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    final label = switch (gen.status) {
      GenerationStatus.connecting => 'Conectando ao modelo...',
      GenerationStatus.thinking => 'Pensando...',
      GenerationStatus.streaming => 'Gerando conteúdo...',
      _ => 'Processando...',
    };

    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: primary),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: onSurface.withValues(alpha: 0.5))),
      ],
    );
  }
}

// ─── Hints de markup ─────────────────────────────────────────────────────────

/// Card de referência da sintaxe de destaque — exibido no card "Destaque".
class _MarkupHint extends StatelessWidget {
  const _MarkupHint();

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sintaxe de destaque:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.55))),
          const SizedBox(height: 8),
          _hlExample(context, '[hl]palavra[/hl]', 'Destaque com a cor padrão acima'),
          const SizedBox(height: 4),
          _hlExample(context, '[hl=#FFF176]palavra[/hl]', 'Destaque com cor hex específica'),
          const SizedBox(height: 4),
          _hlExample(context, '[b]palavra[/b]', 'Negrito inline'),
          const SizedBox(height: 4),
          _hlExample(context, '[i]palavra[/i]', 'Itálico inline'),
          const SizedBox(height: 4),
          _hlExample(context, '[u]palavra[/u]', 'Sublinhado inline'),
          const SizedBox(height: 4),
          _hlExample(context, '[i][u]texto[/u][/i]', 'Tags podem ser combinadas'),
        ],
      ),
    );
  }

  Widget _hlExample(BuildContext context, String code, String desc) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: onSurface.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(code,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(desc,
              style: TextStyle(
                  fontSize: 10, color: onSurface.withValues(alpha: 0.45))),
        ),
      ],
    );
  }
}

/// Mini hint inline exibido abaixo dos campos do slide.
class _MarkupHintInline extends StatelessWidget {
  const _MarkupHintInline();

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Icon(Icons.info_outline,
            size: 11, color: onSurface.withValues(alpha: 0.3)),
        const SizedBox(width: 4),
        Text(
          'Negrito: [b]texto[/b] · Itálico: [i]texto[/i] · Sublinhado: [u]texto[/u] · Destaque: [hl]texto[/hl]',
          style: TextStyle(
              fontSize: 10, color: onSurface.withValues(alpha: 0.4)),
        ),
      ],
    );
  }
}

// ─── Seletor de tipo antes de gerar ─────────────────────────────────────────

class _LayoutTypeSelector extends StatelessWidget {
  final SlideLayout selected;
  final ValueChanged<SlideLayout> onSelect;

  const _LayoutTypeSelector({
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.style_outlined,
                size: 13, color: onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(
              'Tipo de layout',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onSurface.withValues(alpha: 0.65)),
            ),
            const SizedBox(width: 6),
            Text(
              '— define como a IA vai gerar o conteúdo',
              style: TextStyle(
                  fontSize: 11, color: onSurface.withValues(alpha: 0.35)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                icon: Icons.text_fields,
                title: 'Tipo 1',
                subtitle: 'Texto + perfil',
                active: selected == SlideLayout.textPost,
                onTap: () => onSelect(SlideLayout.textPost),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeCard(
                icon: Icons.image_outlined,
                title: 'Tipo 2',
                subtitle: 'Imagem de fundo',
                active: selected == SlideLayout.imageCover,
                onTap: () => onSelect(SlideLayout.imageCover),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeCard(
                icon: Icons.grid_view_outlined,
                title: 'Tipo 3',
                subtitle: 'Grade de textos',
                active: selected == SlideLayout.textGrid,
                onTap: () => onSelect(SlideLayout.textGrid),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _TypeCard(
                icon: Icons.view_agenda_outlined,
                title: 'Tipo 4',
                subtitle: 'Pilha de imagens',
                active: selected == SlideLayout.imageStack,
                onTap: () => onSelect(SlideLayout.imageStack),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.5)
                : outline.withValues(alpha: 0.5),
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: active ? primary : onSurface.withValues(alpha: 0.35)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? onSurface.withValues(alpha: 0.9)
                        : onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? primary.withValues(alpha: 0.7)
                        : onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Cover image picker (Tipo 2) — card destacado ────────────────────────────

class _CoverImagePicker extends StatelessWidget {
  final Uint8List? coverImageBytes;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _CoverImagePicker({
    required this.coverImageBytes,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (coverImageBytes != null) {
      // Mostra o preview com botões de Trocar e Remover sobrepostos
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              coverImageBytes!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Row(
              children: [
                _imageActionBtn(
                  icon: Icons.swap_horiz,
                  label: 'Trocar',
                  onTap: onPick,
                  bg: primary,
                ),
                const SizedBox(width: 6),
                _imageActionBtn(
                  icon: Icons.delete_outline,
                  label: 'Remover',
                  onTap: onClear,
                  bg: Colors.black54,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Sem imagem: botão de upload em destaque
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.06),
          border: Border.all(
            color: primary.withValues(alpha: 0.35),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 28, color: primary.withValues(alpha: 0.7)),
              const SizedBox(height: 6),
              Text(
                'Adicionar imagem de fundo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color bg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Logo picker (Tipo 2) ─────────────────────────────────────────────────────

class _LogoPickerRow extends StatelessWidget {
  final Uint8List? logoBytes;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _LogoPickerRow({
    required this.logoBytes,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Row(
      children: [
        Expanded(
          child: Text('Logo',
              style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.7))),
        ),
        if (logoBytes != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LogoImage(bytes: logoBytes!, height: 28, fit: BoxFit.contain),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 14),
            color: onSurface.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 6),
        ],
        OutlinedButton.icon(
          onPressed: onPick,
          icon: Icon(
            logoBytes != null ? Icons.swap_horiz : Icons.upload_outlined,
            size: 14,
          ),
          label: Text(logoBytes != null ? 'Trocar' : 'Upload',
              style: const TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: outline.withValues(alpha: 0.6)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            minimumSize: Size.zero,
          ),
        ),
      ],
    );
  }
}

class _PosChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _PosChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: active
                ? primary.withValues(alpha: 0.45)
                : onSurface.withValues(alpha: 0.18),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? primary : onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? primary : onSurface.withValues(alpha: 0.55),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Primitivos visuais ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Container(
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.02),
        border: Border.all(color: outline.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: primary.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(title,
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600, letterSpacing: -0.2)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TextBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: onSurface.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

// ─── Seletor de alinhamento (Tipo 3 e 4) ─────────────────────────────────────

class _AlignSelector extends StatelessWidget {
  final TextAlign selected;
  final ValueChanged<TextAlign> onSelect;

  const _AlignSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Text('Alinhamento:',
            style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 10),
        _chip(context, Icons.format_align_left, TextAlign.left, 'Esq.'),
        const SizedBox(width: 6),
        _chip(context, Icons.format_align_center, TextAlign.center, 'Centro'),
        const SizedBox(width: 6),
        _chip(context, Icons.format_align_right, TextAlign.right, 'Dir.'),
      ],
    );
  }

  Widget _chip(BuildContext context, IconData icon, TextAlign align, String label) {
    final primary = Theme.of(context).colorScheme.primary;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final active = selected == align;
    return GestureDetector(
      onTap: () => onSelect(align),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
            color: active ? primary.withValues(alpha: 0.45) : onSurface.withValues(alpha: 0.18),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? primary : onSurface.withValues(alpha: 0.45)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? primary : onSurface.withValues(alpha: 0.55),
                )),
          ],
        ),
      ),
    );
  }
}

// ─── Cores por slide ─────────────────────────────────────────────────────────

class _SlideColorSection extends StatelessWidget {
  final SlideContent slide;
  final ValueChanged<Color?> onBgColor;
  final ValueChanged<Color?> onTextColor;
  final ValueChanged<Color?> onHeadlineColor;
  final ValueChanged<Color?> onBodyColor;
  final ValueChanged<Color?> onSwipeColor;
  final VoidCallback onClear;

  const _SlideColorSection({
    required this.slide,
    required this.onBgColor,
    required this.onTextColor,
    required this.onHeadlineColor,
    required this.onBodyColor,
    required this.onSwipeColor,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cores deste slide',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withValues(alpha: 0.65),
                  ),
                ),
                Text(
                  'Vazio = usa a cor global',
                  style: TextStyle(fontSize: 10, color: onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ),
            const Spacer(),
            if (slide.hasSlideColors)
              GestureDetector(
                onTap: onClear,
                child: Text(
                  'Resetar',
                  style: TextStyle(
                    fontSize: 11,
                    color: primary.withValues(alpha: 0.7),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _colorRow(context, 'Fundo', slide.slideBgColor, onBgColor),
        const SizedBox(height: 10),
        _colorRow(context, 'Texto', slide.slideTextColor, onTextColor),
        const SizedBox(height: 10),
        _colorRow(context, 'Headline', slide.slideHeadlineColor, onHeadlineColor),
        const SizedBox(height: 10),
        _colorRow(context, 'Texto de apoio', slide.slideBodyColor, onBodyColor),
        if (slide.isType2) ...[
          const SizedBox(height: 10),
          _colorRow(context, 'Texto de swipe', slide.swipeTextColor, onSwipeColor),
        ],
      ],
    );
  }

  Widget _colorRow(
    BuildContext context,
    String label,
    Color? selected,
    ValueChanged<Color?> onSelect,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: kBackgroundSwatches.map((c) {
                final isSel = selected != null && c.toARGB32() == selected.toARGB32();
                return GestureDetector(
                  onTap: () => onSelect(isSel ? null : c),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? primary
                            : onSurface.withValues(alpha: 0.2),
                        width: isSel ? 2 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Contador com + e - para tamanho de fonte ─────────────────────────────────

class _StepCounter extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  const _StepCounter({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.decimals = 0,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;
    final canDec = value > min + 1e-9;
    final canInc = value < max - 1e-9;

    String displayValue() {
      if (decimals > 0) return value.toStringAsFixed(decimals);
      return value.round().toString();
    }

    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
        ),
        _btn(context, Icons.remove, canDec ? () => onChanged(double.parse((value - step).clamp(min, max).toStringAsFixed(decimals))) : null, primary, onSurface),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            displayValue(),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onSurface.withValues(alpha: 0.8)),
          ),
        ),
        _btn(context, Icons.add, canInc ? () => onChanged(double.parse((value + step).clamp(min, max).toStringAsFixed(decimals))) : null, primary, onSurface),
      ],
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback? onTap, Color primary, Color onSurface) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: enabled ? primary.withValues(alpha: 0.35) : onSurface.withValues(alpha: 0.15),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15,
            color: enabled ? primary : onSurface.withValues(alpha: 0.25)),
      ),
    );
  }
}

InputDecoration _input(BuildContext context, String hint) {
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  final onSurface = theme.colorScheme.onSurface;
  final outline = theme.colorScheme.outline;
  return InputDecoration(
    hintText: hint,
    hintStyle:
        TextStyle(color: onSurface.withValues(alpha: 0.3), fontSize: 13),
    filled: true,
    fillColor: onSurface.withValues(alpha: 0.03),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: primary.withValues(alpha: 0.45)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

// ─── Dialog de publicação no Instagram (agora ou agendado) ──────────────────

class _PublishDialog extends ConsumerStatefulWidget {
  final List<Uint8List> imagesBytes;
  final String defaultCaption;

  const _PublishDialog({required this.imagesBytes, required this.defaultCaption});

  @override
  ConsumerState<_PublishDialog> createState() => _PublishDialogState();
}

class _PublishDialogState extends ConsumerState<_PublishDialog> {
  late final _captionCtrl = TextEditingController(text: widget.defaultCaption);
  bool _scheduleLater = false;
  DateTime? _scheduledAt;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(minutes: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _scheduledAt ?? now.add(const Duration(minutes: 30))),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    final org = ref.read(activeOrgProvider);
    if (org == null) {
      setState(() => _error = 'Nenhuma organização selecionada');
      return;
    }
    if (_scheduleLater && _scheduledAt == null) {
      setState(() => _error = 'Escolha data e horário do agendamento');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(instagramPublishRepositoryProvider).publish(
            orgId: org.id,
            imagesBytes: widget.imagesBytes,
            caption: _captionCtrl.text.trim(),
            scheduledAt: _scheduleLater ? _scheduledAt : null,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AlertDialog(
      title: const Text('Publicar no Instagram'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.imagesBytes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(widget.imagesBytes[i], height: 160, fit: BoxFit.contain),
                ),
              ),
            ),
            if (widget.imagesBytes.length > 1) ...[
              const SizedBox(height: 6),
              Text(
                'Carrossel com ${widget.imagesBytes.length} slides',
                style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5)),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _captionCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Legenda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Agora'), icon: Icon(Icons.send)),
                ButtonSegment(
                    value: true, label: Text('Agendar'), icon: Icon(Icons.schedule)),
              ],
              selected: {_scheduleLater},
              onSelectionChanged: (s) => setState(() => _scheduleLater = s.first),
            ),
            if (_scheduleLater) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _scheduledAt == null
                      ? 'Escolher data e horário'
                      : '${_scheduledAt!.day.toString().padLeft(2, '0')}/'
                          '${_scheduledAt!.month.toString().padLeft(2, '0')} '
                          '${_scheduledAt!.hour.toString().padLeft(2, '0')}:'
                          '${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Colors.red.withValues(alpha: 0.8), fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_scheduleLater ? 'Agendar' : 'Publicar agora'),
        ),
      ],
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: onSurface.withValues(alpha: 0),
    );
  }
}
