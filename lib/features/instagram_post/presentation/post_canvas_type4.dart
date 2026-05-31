import 'dart:typed_data';

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
  List<Shadow>? shadows,
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
      shadows: shadows,
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
      shadows: shadows,
    );
  }
}

/// Canvas Tipo 4: duas imagens empilhadas 50/50 com texto sobreposto em cada uma.
/// Imagem 1 = imageBytes, Texto 1 = headline.
/// Imagem 2 = coverImageBytes, Texto 2 = body.
class PostCanvasType4 extends StatelessWidget {
  final PostStyle style;
  final SlideContent slide;
  final int index;
  final int total;
  final GlobalKey? boundaryKey;

  const PostCanvasType4({
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _half(slide.imageBytes, slide.headline)),
            Expanded(child: _half(slide.coverImageBytes, slide.body, isBottom: true)),
          ],
        ),
      ),
    );
  }

  Widget _half(Uint8List? imgBytes, String text, {bool isBottom = false}) {
    final align = slide.textAlign;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Imagem de fundo
        _image(imgBytes),
        // Gradiente para legibilidade do texto
        if (text.isNotEmpty)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.4, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
        // Texto sobreposto na base
        if (text.isNotEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: isBottom ? 20 : 14,
            child: _overlayText(text, align),
          ),
        // Contador no canto superior esquerdo apenas da metade de cima
        if (!isBottom)
          Positioned(
            top: 14,
            left: 16,
            child: _counter(),
          ),
        // Seta no canto superior direito da metade de cima
        if (!isBottom && style.showArrows && index < total - 1)
          Positioned(
            top: 10,
            right: 14,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: const Icon(Icons.arrow_forward, size: 15, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _image(Uint8List? bytes) {
    if (bytes == null) {
      return Container(
        color: style.bgColor.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  size: 32, color: style.textColor.withValues(alpha: 0.2)),
              const SizedBox(height: 6),
              Text(
                'Adicionar imagem',
                style: _font(style.bodyFont, size: 11,
                    color: style.textColor.withValues(alpha: 0.28)),
              ),
            ],
          ),
        ),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        color: style.textColor.withValues(alpha: 0.06),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, size: 28, color: Colors.white30),
        ),
      ),
    );
  }

  Widget _overlayText(String text, TextAlign align) {
    final hlColor = style.highlightColor;

    final parts = text.split('\n\n');
    final title = parts.first.trim();
    final sub = parts.length > 1 ? parts.skip(1).join('\n\n').trim() : '';

    final shadow = [
      Shadow(
        color: Colors.black.withValues(alpha: 0.5),
        offset: const Offset(0, 1),
        blurRadius: 4,
      ),
    ];

    final titleStyle = _font(
      style.bodyFont,
      size: style.bodyFontSize * 0.52,
      color: style.resolvedHeadlineColor(),
      weight: style.bold ? FontWeight.w800 : FontWeight.w600,
      style: style.italic ? FontStyle.italic : FontStyle.normal,
      height: 1.15,
      letterSpacing: -0.3,
      shadows: shadow,
    );

    final subStyle = _font(
      style.bodyFont,
      size: style.bodyFontSize * 0.36,
      color: style.resolvedBodyColor(),
      weight: style.bodyBold ? FontWeight.w600 : FontWeight.w400,
      style: style.bodyItalic ? FontStyle.italic : FontStyle.normal,
      height: 1.4,
      shadows: shadow,
    );

    return Column(
      crossAxisAlignment: _crossAxis(align),
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: align,
          text: parseMarkup(title, titleStyle, hlColor) as TextSpan,
        ),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          RichText(
            textAlign: align,
            text: parseMarkup(sub, subStyle, hlColor) as TextSpan,
          ),
        ],
      ],
    );
  }

  Widget _counter() {
    return Text(
      '${index + 1}/$total',
      style: _font(
        style.counterFont,
        size: 12,
        color: Colors.white.withValues(alpha: 0.75),
        weight: FontWeight.w600,
        letterSpacing: 0.5,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 1),
            blurRadius: 3,
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
