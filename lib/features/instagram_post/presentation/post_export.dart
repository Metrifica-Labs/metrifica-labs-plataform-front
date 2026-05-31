import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Captura o RepaintBoundary identificado por [key] como PNG.
/// [pixelRatio] 2.5 sobre o canvas lógico 432x540 produz ~1080x1350px.
Future<Uint8List?> capturePng(GlobalKey key, {double pixelRatio = 2.5}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// Dispara o download de [bytes] como um arquivo PNG no navegador.
void downloadPng(Uint8List bytes, String filename) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// Abre o seletor de arquivos do navegador e devolve os bytes da imagem
/// escolhida (ou null se o usuário cancelar).
/// Aceita formatos raster (png, jpg, webp, gif) e vetorial (svg).
Future<Uint8List?> pickImageBytes({bool allowSvg = false}) {
  final completer = Completer<Uint8List?>();
  final accept = allowSvg ? 'image/*,.svg' : 'image/*';
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = accept;

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      completer.complete(null);
      return;
    }
    final file = files.item(0)!;
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final result = reader.result;
      if (result != null && result.isA<JSArrayBuffer>()) {
        final buffer = (result as JSArrayBuffer).toDart;
        completer.complete(buffer.asUint8List());
      } else {
        completer.complete(null);
      }
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.click();
  return completer.future;
}
