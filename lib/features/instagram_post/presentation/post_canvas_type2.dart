import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/instagram_post_style.dart';
import 'logo_image.dart';
import 'post_canvas.dart' show kCanvasWidth, kCanvasHeight, parseMarkup;

const double _kLogoBadgeH = 30.0;
const double _kLogoBadgeMaxW = 96.0;

TextStyle _font(
  String family, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
  FontStyle style = FontStyle.normal,
  double height = 1.25,
  double letterSpacing = 0,
  List<Shadow>? shadows,
}) {
  const fallbackFamily = 'DM Sans';
  try {
    return GoogleFonts.getFont(
      family,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  } catch (_) {
    return GoogleFonts.getFont(
      fallbackFamily,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      height: height,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }
}

/// Canvas do Tipo 2: imagem full-bleed cobrindo todo o slide (Stack),
/// com logo, título e subtítulo sobrepostos como cards.
class PostCanvasType2 extends StatelessWidget {
  final PostStyle style;
  final SlideContent slide;
  final int index;
  final int total;
  final GlobalKey? boundaryKey;

  const PostCanvasType2({
    super.key,
    required this.style,
    required this.slide,
    required this.index,
    required this.total,
    this.boundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: kCanvasWidth,
        height: kCanvasHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camada 1: fundo full-bleed ──────────────────────────────────
            _background(),
            // ── Camada 2: gradiente preto de baixo pra cima ─────────────────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
            // ── Camada 3: conteúdo sobreposto ───────────────────────────────
            switch (slide.coverVariant) {
              ImageCoverVariant.logoMid => _layoutLogoMid(),
              ImageCoverVariant.logoTop => _layoutLogoTop(),
              ImageCoverVariant.subtitleTop => _layoutSubtitleTop(),
              ImageCoverVariant.logoTopInline => _layoutLogoTopInline(),
            },
          ],
        ),
      ),
    );
  }

  // ── Fundo ─────────────────────────────────────────────────────────────────

  Widget _background() {
    if (slide.coverImageBytes == null) {
      // Placeholder visível no preview — não aparece no export se houver imagem
      return ColoredBox(
        color: style.bgColor.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 48,
                color: style.textColor.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 10),
              Text(
                'Imagem de capa',
                style: _font(
                  style.bodyFont,
                  size: 13,
                  color: style.textColor.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Image.memory(
      slide.coverImageBytes!,
      fit: BoxFit.cover,
      width: kCanvasWidth,
      height: kCanvasHeight,
      errorBuilder:
          (_, __, ___) => ColoredBox(
            color: style.textColor.withValues(alpha: 0.06),
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Colors.white30,
              ),
            ),
          ),
    );
  }

  // ── Variante 1: logo no meio (entre spacer e cards de texto) ──────────────

  Widget _layoutLogoMid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        // Logo centralizado entre imagem e cards
        _logoBadge(),
        // Cards de texto na base
        _textCards(),
        _footer(),
      ],
    );
  }

  // ── Variante 2: logo no topo esquerdo sobreposto, cards na base ───────────

  Widget _layoutLogoTop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 20),
        _logoBadge(),
        const Spacer(),
        _textCards(),
        _footer(),
      ],
    );
  }

  // ── Variante 3: logo no topo, subtítulo ACIMA do título ───────────────────

  Widget _layoutSubtitleTop() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 20),
        _logoBadge(),
        const Spacer(),
        _textCardsInverted(),
        _footer(),
      ],
    );
  }

  // ── Variante 4: logo topo esq + texto inline sobre o gradiente (sem cards) ─

  Widget _layoutLogoTopInline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _logoBadge(),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slide.headline.isNotEmpty) _titleInline(),
              if (slide.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                _subtitleInline(),
              ],
              if (slide.swipeText.isNotEmpty) ...[
                const SizedBox(height: 6),
                _swipeHint(),
              ],
            ],
          ),
        ),
        _footer(),
      ],
    );
  }

  // ── Blocos compartilhados ─────────────────────────────────────────────────

  Widget _logoBadge() {
    if (style.logoBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LogoImage(
          bytes: style.logoBytes!,
          height: _kLogoBadgeH,
          width: _kLogoBadgeMaxW,
          fit: BoxFit.contain,
        ),
      );
    }
    // Fallback: pill com o handle
    return Container(
      height: _kLogoBadgeH,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        //color: style.bgColor.withValues(alpha: 0.9),
      ),
      child: Center(
        child: Text(
          style.handle,
          style: _font(
            style.handleFont,
            size: 11,
            color: style.textColor,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Cards: título então subtítulo
  Widget _textCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slide.headline.isNotEmpty) _titleCard(),
          if (slide.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            _subtitleCard(),
          ],
          if (slide.swipeText.isNotEmpty) ...[
            // const SizedBox(height: 6),
            _swipeHint(),
          ],
        ],
      ),
    );
  }

  // Cards invertidos: subtítulo então título
  Widget _textCardsInverted() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slide.body.isNotEmpty) _subtitleCard(),
          if (slide.headline.isNotEmpty) ...[
            const SizedBox(height: 6),
            _titleCard(),
          ],
          if (slide.swipeText.isNotEmpty) ...[
            const SizedBox(height: 6),
            _swipeHint(),
          ],
        ],
      ),
    );
  }

  Widget _titleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        //borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text:
            parseMarkup(
                  slide.headline,
                  _font(
                    style.bodyFont,
                    size: style.bodyFontSize * 0.82,
                    color: style.resolvedHeadlineColor(),
                    weight: style.bold ? FontWeight.w800 : FontWeight.w600,
                    style: style.italic ? FontStyle.italic : FontStyle.normal,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                  style.highlightColor,
                )
                as TextSpan,
      ),
    );
  }

  Widget _subtitleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        //color: style.bgColor.withValues(alpha: 0.85),
        //borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text:
            parseMarkup(
                  slide.body,
                  _font(
                    style.bodyFont,
                    size: style.bodyFontSize * 0.44,
                    color: style.resolvedBodyColor(),
                    weight: style.bodyBold ? FontWeight.w600 : FontWeight.w400,
                    style:
                        style.bodyItalic ? FontStyle.italic : FontStyle.normal,
                    height: 1.4,
                  ),
                  style.highlightColor,
                )
                as TextSpan,
      ),
    );
  }

  // Título sem card — texto branco diretamente sobre o gradiente
  Widget _titleInline() {
    return RichText(
      text:
          parseMarkup(
                slide.headline,
                _font(
                  style.bodyFont,
                  size: style.bodyFontSize * 0.9,
                  color: Colors.white,
                  weight: style.bold ? FontWeight.w800 : FontWeight.w600,
                  style: style.italic ? FontStyle.italic : FontStyle.normal,
                  height: 1.15,
                  letterSpacing: -0.4,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                style.highlightColor,
              )
              as TextSpan,
    );
  }

  // Subtítulo sem card — branco mais translúcido
  Widget _subtitleInline() {
    return RichText(
      text:
          parseMarkup(
                slide.body,
                _font(
                  style.bodyFont,
                  size: style.bodyFontSize * 0.46,
                  color: Colors.white.withValues(alpha: 0.85),
                  weight: style.bodyBold ? FontWeight.w600 : FontWeight.w400,
                  style: style.bodyItalic ? FontStyle.italic : FontStyle.normal,
                  height: 1.4,
                ),
                style.highlightColor,
              )
              as TextSpan,
    );
  }

  Widget _swipeHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        slide.swipeText,
        textAlign: TextAlign.center,
        style: _font(
          style.counterFont,
          size: 11,
          color: style.resolvedBodyColor(),
          weight: style.bodyBold ? FontWeight.w600 : FontWeight.w400,
          style: style.bodyItalic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _footer() {
    final fg = style.bgColor; // contrasta com a imagem de fundo
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Text(
            '${index + 1}/$total',
            style: _font(
              style.counterFont,
              size: 12,
              color: fg.withValues(alpha: 0.7),
              weight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (style.showArrows && index < total - 1)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withValues(alpha: 0.18),
              ),
              child: Icon(Icons.arrow_forward, size: 16, color: fg),
            ),
        ],
      ),
    );
  }
}
