import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Tipo de layout do slide.
enum SlideLayout {
  /// Tipo 1 — texto com header de perfil, imagem opcional pequena.
  textPost,

  /// Tipo 2 — imagem full-bleed no topo, logo separado, título em card branco.
  imageCover,
}

/// Variante visual do Tipo 2 (posição do logo e ordem dos blocos de texto).
enum ImageCoverVariant {
  /// Logo no meio (entre imagem e título), título abaixo, subtítulo embaixo.
  logoMid,

  /// Logo no canto superior esquerdo (sobre a imagem), título, subtítulo em cards.
  logoTop,

  /// Logo no canto superior, subtítulo acima do título (ordem invertida).
  subtitleTop,

  /// Logo no canto superior esquerdo + texto direto sobre o gradiente (sem cards brancos).
  logoTopInline,
}

/// Um slide do carrossel.
class SlideContent {
  final String headline;
  final String body;

  // ── Tipo 1 ──
  /// Imagem opcional do slide (binário; não persiste no histórico).
  final Uint8List? imageBytes;

  /// true = imagem acima do texto; false = abaixo.
  final bool imageAbove;

  /// Exibe o header de perfil neste slide.
  final bool showHeader;

  // ── Tipo 2 ──
  final SlideLayout layout;

  /// Imagem de fundo full-bleed (Tipo 2).
  final Uint8List? coverImageBytes;

  /// Variante do layout Tipo 2.
  final ImageCoverVariant coverVariant;

  /// Texto opcional de swipe ("Arraste para o lado →").
  final String swipeText;

  const SlideContent({
    required this.headline,
    this.body = '',
    this.imageBytes,
    this.imageAbove = true,
    this.showHeader = true,
    this.layout = SlideLayout.textPost,
    this.coverImageBytes,
    this.coverVariant = ImageCoverVariant.logoMid,
    this.swipeText = '',
  });

  bool get isType2 => layout == SlideLayout.imageCover;

  SlideContent copyWith({
    String? headline,
    String? body,
    Uint8List? imageBytes,
    bool clearImage = false,
    bool? imageAbove,
    bool? showHeader,
    SlideLayout? layout,
    Uint8List? coverImageBytes,
    bool clearCoverImage = false,
    ImageCoverVariant? coverVariant,
    String? swipeText,
  }) => SlideContent(
    headline: headline ?? this.headline,
    body: body ?? this.body,
    imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
    imageAbove: imageAbove ?? this.imageAbove,
    showHeader: showHeader ?? this.showHeader,
    layout: layout ?? this.layout,
    coverImageBytes:
        clearCoverImage ? null : (coverImageBytes ?? this.coverImageBytes),
    coverVariant: coverVariant ?? this.coverVariant,
    swipeText: swipeText ?? this.swipeText,
  );
}

/// Fontes Google disponíveis.
const kAvailableFonts = <String>[
  'Inter',
  'Poppins',
  'Montserrat',
  'Sequel Sans',
  'Playfair Display',
  'Lora',
  'Roboto Slab',
  'Oswald',
  'Bebas Neue',
  'Archivo',
  'Space Grotesk',
  'DM Sans',
  'Libre Baskerville',
];

class CreatorPreset {
  final String name;
  final Color bgColor;
  final Color textColor;
  final String nameFont;
  final String handleFont;
  final String bodyFont;
  final String counterFont;

  const CreatorPreset({
    required this.name,
    required this.bgColor,
    required this.textColor,
    required this.nameFont,
    required this.handleFont,
    required this.bodyFont,
    required this.counterFont,
  });
}

const kCreatorPresets = <CreatorPreset>[
  CreatorPreset(
    name: 'Clean',
    bgColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF101012),
    nameFont: 'Inter',
    handleFont: 'Inter',
    bodyFont: 'Inter',
    counterFont: 'Inter',
  ),
  CreatorPreset(
    name: 'Dark',
    bgColor: Color(0xFF0E0E12),
    textColor: Color(0xFFF4F4F6),
    nameFont: 'Space Grotesk',
    handleFont: 'DM Sans',
    bodyFont: 'DM Sans',
    counterFont: 'Space Grotesk',
  ),
  CreatorPreset(
    name: 'Editorial',
    bgColor: Color(0xFFF5F1E8),
    textColor: Color(0xFF1A1A1A),
    nameFont: 'Playfair Display',
    handleFont: 'Lora',
    bodyFont: 'Lora',
    counterFont: 'Playfair Display',
  ),
  CreatorPreset(
    name: 'Bold Blue',
    bgColor: Color(0xFF236BF7),
    textColor: Color(0xFFFFFFFF),
    nameFont: 'Montserrat',
    handleFont: 'Montserrat',
    bodyFont: 'Poppins',
    counterFont: 'Montserrat',
  ),
  CreatorPreset(
    name: 'Punch',
    bgColor: Color(0xFFFCE300),
    textColor: Color(0xFF101012),
    nameFont: 'Oswald',
    handleFont: 'Archivo',
    bodyFont: 'Archivo',
    counterFont: 'Bebas Neue',
  ),
];

const kBackgroundSwatches = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFF0E0E12),
  Color(0xFF236BF7),
  Color(0xFF111B2E),
  Color(0xFFF5F1E8),
  Color(0xFFFCE300),
  Color(0xFFFF5A5F),
  Color(0xFF1DB954),
  Color(0xFF6C2BD9),
  Color(0xFFEC4899),
];

/// Cores de destaque para uso com a syntax `[hl]...[/hl]`.
const kHighlightSwatches = <Color>[
  Color(0xFFFFF176),
  Color(0xFFFFCC80),
  Color(0xFFA5D6A7),
  Color(0xFF80DEEA),
  Color(0xFFCF94DA),
  Color(0xFFEF9A9A),
  Color(0xFFFFFFFF),
  Color(0xFF000000),
];

/// Estado imutável do editor de post.
class PostStyle {
  // Perfil
  final Uint8List? avatarBytes;
  final String profileName;
  final String handle;
  final double avatarRadius;
  final bool showVerifiedBadge;

  // Logo separado para Tipo 2 (retangular, upload independente)
  final Uint8List? logoBytes;

  // Layout padrão para novos slides gerados pela IA
  final SlideLayout defaultLayout;

  // Layout visual
  /// Quando true, o bloco header+body fica verticalmente centralizado no canvas;
  /// o footer (contador + seta) permanece fixo na base.
  final bool centerContent;

  // 4 fontes
  final String nameFont;
  final String handleFont;
  final String bodyFont;
  final String counterFont;

  // Ênfase — headline
  final bool bold;
  final bool italic;
  final bool underline;

  // Ênfase — body (texto de apoio)
  final bool bodyBold;
  final bool bodyItalic;
  final bool bodyUnderline;

  // Cor padrão do destaque inline `[hl]...[/hl]`
  final Color highlightColor;

  // Cores globais
  final Color bgColor;
  final Color textColor;

  // Cores individuais (null = herda de textColor)
  final Color? headlineColor;
  final Color? bodyColor;

  // Extras
  final bool showArrows;
  final double bodyFontSize;

  final List<SlideContent> slides;

  const PostStyle({
    this.avatarBytes,
    this.logoBytes,
    this.profileName = 'Seu Nome',
    this.handle = '@seuperfil',
    this.avatarRadius = 26,
    this.showVerifiedBadge = false,
    this.defaultLayout = SlideLayout.textPost,
    this.centerContent = true,
    this.nameFont = 'Inter',
    this.handleFont = 'Inter',
    this.bodyFont = 'Inter',
    this.counterFont = 'Inter',
    this.bold = true,
    this.italic = false,
    this.underline = false,
    this.bodyBold = false,
    this.bodyItalic = false,
    this.bodyUnderline = false,
    this.highlightColor = const Color(0xFFFFF176),
    this.bgColor = const Color(0xFFFFFFFF),
    this.textColor = const Color(0xFF101012),
    this.headlineColor,
    this.bodyColor,
    this.showArrows = true,
    this.bodyFontSize = 30,
    this.slides = const [],
  });

  bool get hasSlides => slides.isNotEmpty;

  Color resolvedHeadlineColor() => headlineColor ?? textColor;
  Color resolvedBodyColor() => bodyColor ?? textColor.withValues(alpha: 0.72);

  PostStyle copyWith({
    Uint8List? avatarBytes,
    bool clearAvatar = false,
    Uint8List? logoBytes,
    bool clearLogo = false,
    String? profileName,
    String? handle,
    double? avatarRadius,
    bool? showVerifiedBadge,
    bool? centerContent,
    String? nameFont,
    String? handleFont,
    String? bodyFont,
    String? counterFont,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? bodyBold,
    bool? bodyItalic,
    bool? bodyUnderline,
    Color? highlightColor,
    Color? bgColor,
    Color? textColor,
    Color? headlineColor,
    bool clearHeadlineColor = false,
    Color? bodyColor,
    bool clearBodyColor = false,
    SlideLayout? defaultLayout,
    bool? showArrows,
    double? bodyFontSize,
    List<SlideContent>? slides,
  }) => PostStyle(
    avatarBytes: clearAvatar ? null : (avatarBytes ?? this.avatarBytes),
    logoBytes: clearLogo ? null : (logoBytes ?? this.logoBytes),
    profileName: profileName ?? this.profileName,
    handle: handle ?? this.handle,
    avatarRadius: avatarRadius ?? this.avatarRadius,
    showVerifiedBadge: showVerifiedBadge ?? this.showVerifiedBadge,
    defaultLayout: defaultLayout ?? this.defaultLayout,
    centerContent: centerContent ?? this.centerContent,
    nameFont: nameFont ?? this.nameFont,
    handleFont: handleFont ?? this.handleFont,
    bodyFont: bodyFont ?? this.bodyFont,
    counterFont: counterFont ?? this.counterFont,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    bodyBold: bodyBold ?? this.bodyBold,
    bodyItalic: bodyItalic ?? this.bodyItalic,
    bodyUnderline: bodyUnderline ?? this.bodyUnderline,
    highlightColor: highlightColor ?? this.highlightColor,
    bgColor: bgColor ?? this.bgColor,
    textColor: textColor ?? this.textColor,
    headlineColor:
        clearHeadlineColor ? null : (headlineColor ?? this.headlineColor),
    bodyColor: clearBodyColor ? null : (bodyColor ?? this.bodyColor),
    showArrows: showArrows ?? this.showArrows,
    bodyFontSize: bodyFontSize ?? this.bodyFontSize,
    slides: slides ?? this.slides,
  );

  PostStyle applyPreset(CreatorPreset p) => copyWith(
    bgColor: p.bgColor,
    textColor: p.textColor,
    clearHeadlineColor: true,
    clearBodyColor: true,
    nameFont: p.nameFont,
    handleFont: p.handleFont,
    bodyFont: p.bodyFont,
    counterFont: p.counterFont,
  );
}

// ── Parser de slides ──────────────────────────────────────────────────────────

List<SlideContent> parseSlides(
  String output, {
  SlideLayout defaultLayout = SlideLayout.textPost,
}) {
  final block = _firstJsonBlock(output) ?? output.trim();
  try {
    final decoded = jsonDecode(block);
    if (decoded is Map && decoded['slides'] is List) {
      final slides = <SlideContent>[];
      for (final raw in decoded['slides'] as List) {
        if (raw is Map) {
          final headline = (raw['headline'] ?? '').toString().trim();
          final body = (raw['body'] ?? '').toString().trim();
          final swipeText =
              (raw['swipeText'] ?? raw['swipe_text'] ?? '').toString().trim();
          if (headline.isNotEmpty || body.isNotEmpty) {
            slides.add(
              SlideContent(
                headline: headline,
                body: body,
                layout: defaultLayout,
                swipeText: swipeText,
              ),
            );
          }
        } else if (raw is String && raw.trim().isNotEmpty) {
          slides.add(SlideContent(headline: raw.trim(), layout: defaultLayout));
        }
      }
      if (slides.isNotEmpty) return slides;
    }
  } catch (_) {}
  return _fallbackSlides(output, defaultLayout: defaultLayout);
}

String? _firstJsonBlock(String text) {
  final matches =
      RegExp(r'```(?:\w*\n)?([\s\S]+?)```').allMatches(text).toList();
  if (matches.isEmpty) return null;
  for (final m in matches) {
    final content = m.group(1)?.trim() ?? '';
    if (content.startsWith('{') && content.contains('"slides"')) return content;
  }
  return matches.first.group(1)?.trim();
}

List<SlideContent> _fallbackSlides(
  String output, {
  SlideLayout defaultLayout = SlideLayout.textPost,
}) {
  final cleaned = output.replaceAll(RegExp(r'```[\s\S]*?```'), '').trim();
  if (cleaned.isEmpty) return const [];
  final chunks =
      cleaned
          .split(RegExp(r'\n\s*\n'))
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty)
          .toList();
  if (chunks.isEmpty) return [SlideContent(headline: cleaned)];
  return chunks.map((c) {
    final lines = c.split('\n');
    final headline = lines.first.replaceAll(RegExp(r'^#+\s*'), '').trim();
    final body = lines.skip(1).join('\n').trim();
    return SlideContent(headline: headline, body: body, layout: defaultLayout);
  }).toList();
}
