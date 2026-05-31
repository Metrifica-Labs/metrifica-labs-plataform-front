import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../generation/data/generation_notifier.dart';
import '../../generation/data/generation_state.dart';
import '../data/ig_post_history.dart';
import '../data/instagram_post_notifier.dart';
import '../data/instagram_post_style.dart';
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

  @override
  void dispose() {
    _briefingCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final gen = ref.watch(generationProvider);
    final style = ref.watch(instagramPostProvider);

    // Em debug: restaura o último histórico automaticamente ao abrir a página.
    if (kDebugMode && !_debugRestored && !style.hasSlides) {
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
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
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
              const SizedBox(height: 28),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: controls),
                    const SizedBox(width: 32),
                    SizedBox(width: 380, child: preview),
                  ],
                )
              else ...[
                preview,
                const SizedBox(height: 28),
                controls,
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Coluna de preview ────────────────────────────────────────────────────────

class _PreviewColumn extends StatelessWidget {
  final PostStyle style;
  final int current;
  final GlobalKey boundaryKey;
  final bool exporting;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onExportCurrent;
  final VoidCallback? onExportAll;

  const _PreviewColumn({
    required this.style,
    required this.current,
    required this.boundaryKey,
    required this.exporting,
    required this.onPrev,
    required this.onNext,
    required this.onExportCurrent,
    required this.onExportAll,
  });

  @override
  Widget build(BuildContext context) {
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

    return Column(
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
      ],
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
        // ── Briefing / geração ─────────────────────────────────────────────
        _Card(
          title: 'Conteúdo (IA)',
          icon: Icons.auto_awesome,
          trailing: gen.status != GenerationStatus.idle
              ? _TextBtn(label: 'Novo', icon: Icons.refresh, onTap: onReset)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Seletor de tipo de layout (influencia a IA) ───────────────
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
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
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
              onTextAlign: (v) =>
                  notifier.setSlideTextAlign(currentIndex, v),
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
        _SliderRow(label: 'Tamanho', value: style.bodyFontSize,
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

    final highlightCard = _Card(
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
        highlightCard,
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
        highlightCard,
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
          _SliderRow(label: 'Tamanho do círculo', value: style.avatarRadius,
              min: 16, max: 44, onChanged: notifier.setAvatarRadius),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _Toggle(label: 'Verificado', icon: Icons.verified,
                active: style.showVerifiedBadge, onTap: notifier.toggleVerifiedBadge),
            _Toggle(label: 'Centralizado', icon: Icons.vertical_align_center,
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
      highlightCard,
      const SizedBox(height: 16),
      extrasCard,
      const SizedBox(height: 16),
      _Card(
        title: 'Cores',
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

  static const _swatches = <Color>[
    Color(0xFF101012),
    Color(0xFFFFFFFF),
    Color(0xFF236BF7),
    Color(0xFF6E6E73),
    Color(0xFFFF5A5F),
    Color(0xFF1DB954),
    Color(0xFFFCE300),
    Color(0xFFEC4899),
  ];

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
          children: _swatches.map((c) {
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
  final ValueChanged<SlideLayout> onLayout;
  final VoidCallback onPickCoverImage;
  final VoidCallback onClearCoverImage;
  final ValueChanged<ImageCoverVariant> onCoverVariant;
  final ValueChanged<String> onSwipeText;
  final void Function(int blockIdx, String text) onGridText;
  final ValueChanged<TextAlign> onTextAlign;

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
    required this.onLayout,
    required this.onPickCoverImage,
    required this.onClearCoverImage,
    required this.onCoverVariant,
    required this.onSwipeText,
    required this.onGridText,
    required this.onTextAlign,
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
                label: 'Logo centro',
                icon: Icons.location_on_outlined,
                active: slide.coverVariant == ImageCoverVariant.logoMid,
                onTap: () => onCoverVariant(ImageCoverVariant.logoMid),
              ),
              _PosChip(
                label: 'Logo topo',
                icon: Icons.vertical_align_top,
                active: slide.coverVariant == ImageCoverVariant.logoTop,
                onTap: () => onCoverVariant(ImageCoverVariant.logoTop),
              ),
              _PosChip(
                label: 'Subtítulo acima',
                icon: Icons.swap_vert,
                active: slide.coverVariant == ImageCoverVariant.subtitleTop,
                onTap: () => onCoverVariant(ImageCoverVariant.subtitleTop),
              ),
              _PosChip(
                label: 'Logo topo + inline',
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
          _AlignSelector(
            selected: slide.textAlign,
            onSelect: onTextAlign,
          ),
          const SizedBox(height: 12),
          Text('Bloco topo esquerdo:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          _MiniField(
            key: ValueKey('g0-$currentIndex'),
            label: 'Texto (opcional)',
            value: slide.gridTexts.isNotEmpty ? slide.gridTexts[0] : '',
            maxLines: 4,
            onChanged: (v) => onGridText(0, v),
          ),
          const SizedBox(height: 10),
          Text('Bloco topo direito:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          _MiniField(
            key: ValueKey('g1-$currentIndex'),
            label: 'Texto (opcional)',
            value: slide.gridTexts.length > 1 ? slide.gridTexts[1] : '',
            maxLines: 4,
            onChanged: (v) => onGridText(1, v),
          ),
          const SizedBox(height: 12),
          _CoverImagePicker(
            coverImageBytes: slide.coverImageBytes,
            onPick: onPickCoverImage,
            onClear: onClearCoverImage,
          ),
          const SizedBox(height: 12),
          Text('Bloco base esquerdo:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          _MiniField(
            key: ValueKey('g2-$currentIndex'),
            label: 'Texto (opcional)',
            value: slide.gridTexts.length > 2 ? slide.gridTexts[2] : '',
            maxLines: 4,
            onChanged: (v) => onGridText(2, v),
          ),
          const SizedBox(height: 10),
          Text('Bloco base direito:',
              style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          _MiniField(
            key: ValueKey('g3-$currentIndex'),
            label: 'Texto (opcional)',
            value: slide.gridTexts.length > 3 ? slide.gridTexts[3] : '',
            maxLines: 4,
            onChanged: (v) => onGridText(3, v),
          ),
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
        ],
      ],
    );
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

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 28,
          child: Text(value.round().toString(),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 11, color: onSurface.withValues(alpha: 0.5))),
        ),
      ],
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
          'Destaque: [hl]texto[/hl] · Itálico: [i]texto[/i] · Sublinhado: [u]texto[/u]',
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
          child: Text('Logo (Tipo 2)',
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
