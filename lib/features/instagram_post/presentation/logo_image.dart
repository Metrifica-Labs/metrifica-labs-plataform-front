import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Retorna true se os bytes representam um arquivo SVG.
bool isSvgBytes(Uint8List bytes) {
  if (bytes.length < 4) return false;
  // SVG começa com '<svg' ou '<?xml', ambos com byte '<' (0x3C).
  // Busca o primeiro '<' nos primeiros 64 bytes (ignora BOM UTF-8).
  final prefix = bytes.take(64).toList();
  final ltIndex = prefix.indexOf(0x3C); // '<'
  if (ltIndex < 0) return false;
  final tail = String.fromCharCodes(prefix.skip(ltIndex).take(10));
  return tail.startsWith('<svg') || tail.startsWith('<?xml');
}

/// Renderiza bytes de imagem detectando automaticamente SVG vs raster.
/// Para SVGs usa [SvgPicture.memory]; para raster usa [Image.memory].
class LogoImage extends StatelessWidget {
  final Uint8List bytes;
  final double? width;
  final double? height;
  final BoxFit fit;

  const LogoImage({
    super.key,
    required this.bytes,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (isSvgBytes(bytes)) {
      return SvgPicture.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
      );
    }
    return Image.memory(
      bytes,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
