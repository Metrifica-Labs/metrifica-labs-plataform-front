import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/instagram_post_style.dart';
import 'post_canvas.dart' show kCanvasWidth, kCanvasHeight, parseMarkup;

// Canvas do Tipo 5 (Freestyle) — clone do Tipo 1 (PostCanvas).
// Mantido como widget separado para receber, daqui em diante, as alterações
// específicas do estilo livre sem afetar o Tipo 1.

TextStyle _font(
  String family, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
  FontStyle style = FontStyle.normal,
  TextDecoration decoration = TextDecoration.none,
  double height = 1.25,
  double letterSpacing = 0,
}) {
  const fallbackFamily = 'DM Sans';
  try {
    return GoogleFonts.getFont(
      family,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      decoration: decoration,
      decorationColor: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  } catch (_) {
    return GoogleFonts.getFont(
      fallbackFamily,
      fontSize: size,
      color: color,
      fontWeight: weight,
      fontStyle: style,
      decoration: decoration,
      decorationColor: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

class PostCanvasFreestyle extends StatelessWidget {
  final PostStyle style;
  final SlideContent slide;
  final int index;
  final int total;
  final GlobalKey? boundaryKey;

  const PostCanvasFreestyle({
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
      child: Container(
        width: kCanvasWidth,
        height: kCanvasHeight,
        color: slide.resolvedBg(style),
        padding: const EdgeInsets.fromLTRB(34, 30, 34, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    style.centerContent
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                children: [
                  if (slide.imageBytes != null &&
                      slide.imagePosition == SlideImagePosition.above) ...[
                    _slideImage(),
                    const SizedBox(height: 16),
                  ],
                  _body(),
                  if (slide.imageBytes != null &&
                      slide.imagePosition == SlideImagePosition.below) ...[
                    const SizedBox(height: 16),
                    _slideImage(),
                  ],
                ],
              ),
            ),
            // Footer: sempre fixo na base.
            const SizedBox(height: 10),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final headlineC = slide.resolvedHeadlineFor(style);
    final bodyC = slide.resolvedBodyFor(style);
    final hlColor = style.highlightColor;
    final cColor = style.textAccentColor;

    final headlineBase = _font(
      style.bodyFont,
      size: style.bodyFontSize,
      color: headlineC,
      weight: style.bold ? FontWeight.w800 : FontWeight.w500,
      style: style.italic ? FontStyle.italic : FontStyle.normal,
      decoration:
          style.underline ? TextDecoration.underline : TextDecoration.none,
      height: 1.18,
      letterSpacing: -0.4,
    );

    final bodyBase = _font(
      style.bodyFont,
      size: style.bodyFontSize * 0.5,
      color: bodyC,
      weight: style.bodyBold ? FontWeight.w700 : FontWeight.w400,
      style: style.bodyItalic ? FontStyle.italic : FontStyle.normal,
      decoration:
          style.bodyUnderline ? TextDecoration.underline : TextDecoration.none,
      height: 1.45,
    );

    final showMiddleImage = slide.imageBytes != null &&
        slide.imagePosition == SlideImagePosition.middle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.headline.isNotEmpty)
          RichText(
            text: parseMarkup(slide.headline, headlineBase, hlColor,
                cColor: cColor) as TextSpan,
          ),
        if (showMiddleImage) ...[
          SizedBox(height: slide.headline.isNotEmpty ? 16 : 0),
          _slideImage(),
        ],
        if (slide.body.isNotEmpty) ...[
          SizedBox(
            height:
                slide.headline.isNotEmpty || showMiddleImage ? 16 : 0,
          ),
          RichText(
            text: parseMarkup(slide.body, bodyBase, hlColor, cColor: cColor)
                as TextSpan,
          ),
        ],
      ],
    );
  }

  Widget _slideImage() {
    final fg = slide.resolvedText(style);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        slide.imageBytes!,
        width:
            kCanvasWidth - 68, // largura do canvas menos o padding horizontal
        height: 168,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Container(
              width: kCanvasWidth - 68,
              height: 168,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.broken_image_outlined,
                size: 32,
                color: fg.withValues(alpha: 0.2),
              ),
            ),
      ),
    );
  }

  Widget _footer() {
    final fg = slide.resolvedText(style);
    return Row(
      children: [
        Text(
          style.handle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _font(
            style.handleFont,
            size: 13,
            color: fg.withValues(alpha: 0.55),
            weight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '${index + 1}/$total',
          style: _font(
            style.counterFont,
            size: 13,
            color: fg.withValues(alpha: 0.5),
            weight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
