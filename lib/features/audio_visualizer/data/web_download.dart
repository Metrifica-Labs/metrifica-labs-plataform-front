import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Dispara o download de [bytes] como arquivo no navegador.
void downloadBytes(Uint8List bytes, String filename, String mimeType) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  a.click();
  web.URL.revokeObjectURL(url);
}

/// Abre o seletor de arquivos com [accept] e devolve (nome, bytes) ou null.
Future<(String, Uint8List)?> pickFileBytes(String accept) {
  final completer = Completer<(String, Uint8List)?>();
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
        completer.complete((file.name, buffer.asUint8List()));
      } else {
        completer.complete(null);
      }
    }.toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  input.click();
  return completer.future;
}
