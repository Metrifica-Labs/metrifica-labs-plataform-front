import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/instagram_post_style.dart';

const double kCanvasWidth = 432;
const double kCanvasHeight = 540;

// ── Markup inline ─────────────────────────────────────────────────────────────
//
// Tags suportadas (abrir/fechar):
//   [hl]palavra[/hl]          → destaque com highlightColor configurado
//   [hl=#FFF176]palavra[/hl]  → destaque com cor hexadecimal específica
//   [i]palavra[/i]            → itálico inline
//   [u]palavra[/u]            → sublinhado inline
//
// Tags podem ser combinadas aninhando: [i][u]texto[/u][/i]

// Regex que captura qualquer tag suportada:
// grupo 1 = tag de abertura completa (ex: 'hl=#FFF176', 'i', 'u')
// grupo 2 = conteúdo
// grupo 3 = tag de fechamento ('hl', 'i', 'u')
final markupPattern = RegExp(
  r'\[(hl(?:=#[0-9A-Fa-f]{6,8})?|i|u|b)\](.*?)\[/(hl|i|u|b)\]',
  dotAll: true,
);

// Alias privado para compatibilidade interna
final _markupPattern = markupPattern;

/// Parseia o markup inline e devolve um [TextSpan] com estilos aplicados.
/// Público para uso em outros widgets de canvas.
InlineSpan parseMarkup(String text, TextStyle base, Color hlColor) {
  final spans = <InlineSpan>[];
  var lastEnd = 0;

  for (final m in _markupPattern.allMatches(text)) {
    final openTag = m.group(1)!; // ex: 'hl=#FFF176', 'i', 'u'
    final closeTag = m.group(3)!; // ex: 'hl', 'i', 'u'
    final content = m.group(2) ?? '';

    // Garante que abertura e fechamento correspondem (ex: [i] fecha com [/i])
    final openBase = openTag.startsWith('hl') ? 'hl' : openTag;
    if (openBase != closeTag) continue;

    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start), style: base));
    }

    final TextStyle spanStyle;
    switch (closeTag) {
      case 'hl':
        // Extrai o hex após 'hl=#'
        final hexPart = openTag.length > 3 ? openTag.substring(4) : null;
        final color =
            hexPart != null
                ? Color(
                  int.parse(
                    hexPart.length == 8 ? hexPart : 'FF$hexPart',
                    radix: 16,
                  ),
                )
                : hlColor;
        spanStyle = base.copyWith(
          backgroundColor: color.withValues(alpha: 0.6),
        );
      case 'i':
        spanStyle = base.copyWith(fontStyle: FontStyle.italic);
      case 'u':
        spanStyle = base.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: base.color,
        );
      case 'b':
        spanStyle = base.copyWith(fontWeight: FontWeight.w700);
      default:
        spanStyle = base;
    }

    // Processa recursivamente para suportar tags aninhadas
    spans.add(parseMarkup(content, spanStyle, hlColor) as TextSpan);
    lastEnd = m.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd), style: base));
  }

  if (spans.isEmpty) return TextSpan(text: text, style: base);
  if (spans.length == 1) return spans.first;
  return TextSpan(children: spans, style: base);
}

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

class PostCanvas extends StatelessWidget {
  final PostStyle style;
  final SlideContent slide;
  final int index;
  final int total;
  final GlobalKey? boundaryKey;

  const PostCanvas({
    super.key,
    required this.style,
    required this.slide,
    required this.index,
    required this.total,
    this.boundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;

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
                  if (slide.showHeader) ...[
                    _header(),
                    const SizedBox(height: 24),
                  ],
                  if (slide.imageBytes != null && slide.imageAbove) ...[
                    _slideImage(),
                    const SizedBox(height: 16),
                  ],
                  _body(),
                  if (slide.imageBytes != null && !slide.imageAbove) ...[
                    const SizedBox(height: 16),
                    _slideImage(),
                  ],
                ],
              ),
            ),
            // Footer: sempre fixo na base.
            const SizedBox(height: 10),
            _footer(isLast),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final fg = slide.resolvedText(style);
    final r = style.avatarRadius;

    final avatar = Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fg.withValues(alpha: 0.08),
        image:
            style.avatarBytes != null
                ? DecorationImage(
                  image: MemoryImage(style.avatarBytes!),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      child:
          style.avatarBytes == null
              ? Icon(Icons.person, size: r, color: fg.withValues(alpha: 0.35))
              : null,
    );

    final nameRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            style.profileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _font(
              style.nameFont,
              size: 17,
              color: fg,
              weight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        if (style.showVerifiedBadge) ...[
          const SizedBox(width: 5),
          const Icon(Icons.verified, size: 16, color: Color(0xFF1D9BF0)),
        ],
      ],
    );

    final handleText = Text(
      style.handle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _font(
        style.handleFont,
        size: 13,
        color: fg.withValues(alpha: 0.55),
        height: 1.1,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        avatar,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [nameRow, const SizedBox(height: 1), handleText],
          ),
        ),
      ],
    );
  }

  Widget _body() {
    final headlineC = slide.resolvedHeadlineFor(style);
    final bodyC = slide.resolvedBodyFor(style);
    final hlColor = style.highlightColor;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.headline.isNotEmpty)
          RichText(
            text:
                parseMarkup(slide.headline, headlineBase, hlColor) as TextSpan,
          ),
        if (slide.body.isNotEmpty) ...[
          SizedBox(height: slide.headline.isNotEmpty ? 16 : 0),
          RichText(
            text: parseMarkup(slide.body, bodyBase, hlColor) as TextSpan,
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

  Widget _footer(bool isLast) {
    final fg = slide.resolvedText(style);
    return Row(
      children: [
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
        const Spacer(),
        if (style.showArrows && !isLast)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fg.withValues(alpha: 0.1),
            ),
            child: Icon(Icons.arrow_forward, size: 18, color: fg),
          ),
      ],
    );
  }
}
