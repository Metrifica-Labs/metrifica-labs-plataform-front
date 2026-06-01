import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/instagram_post_style.dart';
import 'post_canvas.dart' show kCanvasWidth, kCanvasHeight, parseMarkup;

TextStyle _font(
  String family, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
  FontStyle style = FontStyle.normal,
  double height = 1.3,
  double letterSpacing = 0,
}) {
  const fallback = 'DM Sans';
  try {
    return GoogleFonts.getFont(
      family,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      height: height,
      letterSpacing: letterSpacing,
    );
  } catch (_) {
    return GoogleFonts.getFont(
      fallback,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// Canvas Tipo 3: imagem full-bleed de fundo com grade 2×2 de textos sobreposta.
class PostCanvasType3 extends StatelessWidget {
  final PostStyle style;
  final SlideContent slide;
  final int index;
  final int total;
  final GlobalKey? boundaryKey;

  const PostCanvasType3({
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
            // Fundo full-bleed
            _background(),
            // Grade de textos + footer sobrepostos
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Linha de topo
                  Expanded(child: _textRow(0, 1)),
                  // Linha de base
                  Expanded(child: _textRow(2, 3)),
                  const SizedBox(height: 8),
                  _footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _background() {
    if (slide.coverImageBytes == null) {
      return Container(
        color: slide.resolvedBg(style),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 48, color: slide.resolvedText(style).withValues(alpha: 0.15)),
              const SizedBox(height: 10),
              Text(
                'Imagem de fundo',
                style: _font(style.bodyFont, size: 13,
                    color: slide.resolvedText(style).withValues(alpha: 0.25)),
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
      errorBuilder: (_, __, ___) => Container(
        color: slide.resolvedText(style).withValues(alpha: 0.06),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.white30),
        ),
      ),
    );
  }

  Widget _textRow(int leftIdx, int rightIdx) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _textBlock(leftIdx)),
        const SizedBox(width: 12),
        Expanded(child: _textBlock(rightIdx)),
      ],
    );
  }

  Widget _textBlock(int idx) {
    final texts = slide.gridTexts;
    final text = idx < texts.length ? texts[idx] : '';
    final align = slide.textAlign;
    final isBold = idx < slide.gridBolds.length && slide.gridBolds[idx];

    if (text.isEmpty) return const SizedBox.expand();

    final textStyle = _font(
      style.bodyFont,
      size: style.bodyFontSize * 0.44,
      color: slide.resolvedBodyFor(style),
      weight: isBold ? FontWeight.w700 : FontWeight.w400,
      style: style.bodyItalic ? FontStyle.italic : FontStyle.normal,
      height: slide.gridSpacing,
    );

    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: _crossAxis(align),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RichText(
            textAlign: align,
            text: parseMarkup(text, textStyle, style.highlightColor) as TextSpan,
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final fg = slide.resolvedText(style);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (slide.showCounter)
            Text(
              '${index + 1}/$total',
              style: _font(style.counterFont, size: 12,
                  color: fg.withValues(alpha: 0.7),
                  weight: FontWeight.w600, letterSpacing: 0.5),
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

  CrossAxisAlignment _crossAxis(TextAlign align) => switch (align) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.right => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.start,
      };
}
