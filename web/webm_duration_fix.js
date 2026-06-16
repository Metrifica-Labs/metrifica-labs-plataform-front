// Corrige a duracao ausente/infinita em arquivos .webm gravados via
// MediaRecorder. O MediaRecorder grava o container em modo "streaming"
// (tamanho do Segment desconhecido) e normalmente nao grava a duracao
// final no elemento EBML Info > Duration, o que faz o arquivo aparecer
// como "Infinity"/0:00 em players, conversores e apps de mensagem.
//
// Esta funcao localiza (ou insere, se ausente) o elemento Duration dentro
// de Segment > Info e grava o valor correto, sem precisar reconstruir o
// resto do arquivo.
(function () {
  function readVint(bytes, offset, isId) {
    var first = bytes[offset];
    var length = 1;
    var mask = 0x80;
    while (length <= 8 && !(first & mask)) {
      mask >>= 1;
      length++;
    }
    if (length > 8) return null;

    var value;
    var isUnknown = false;
    if (isId) {
      value = first;
      for (var i = 1; i < length; i++) {
        value = value * 256 + bytes[offset + i];
      }
    } else {
      var firstValueBits = first & (mask - 1);
      value = firstValueBits;
      var allOnes = firstValueBits === (mask - 1);
      for (var i = 1; i < length; i++) {
        value = value * 256 + bytes[offset + i];
        allOnes = allOnes && bytes[offset + i] === 0xff;
      }
      isUnknown = allOnes;
    }
    return { length: length, value: value, isUnknown: isUnknown };
  }

  function findElement(bytes, start, end, targetId) {
    var offset = start;
    while (offset < end) {
      var id = readVint(bytes, offset, true);
      if (!id) return null;
      var idEnd = offset + id.length;
      var size = readVint(bytes, idEnd, false);
      if (!size) return null;
      var contentStart = idEnd + size.length;
      var contentEnd = size.isUnknown ? end : contentStart + size.value;

      if (id.value === targetId) {
        return {
          contentStart: contentStart,
          contentEnd: contentEnd,
          sizeValue: size.value,
          sizeLength: size.length,
          sizeOffset: idEnd,
        };
      }
      if (size.isUnknown) return null;
      offset = contentEnd;
    }
    return null;
  }

  function writeFloatAt(view, offset, size, value) {
    var buf = new ArrayBuffer(size);
    if (size === 8) {
      new Float64Array(buf)[0] = value;
    } else {
      new Float32Array(buf)[0] = value;
    }
    var little = new Uint8Array(buf);
    for (var i = 0; i < size; i++) {
      view[offset + i] = little[size - 1 - i];
    }
  }

  function encodeVintValue(value, length) {
    var bytes = new Uint8Array(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = v & 0xff;
      v = Math.floor(v / 256);
    }
    bytes[0] |= 0x80 >> (length - 1);
    return bytes;
  }

  window.fixWebmDuration = function (bytes, durationSeconds) {
    try {
      var EBML_ID = 0x1a45dfa3;
      var SEGMENT_ID = 0x18538067;
      var INFO_ID = 0x1549a966;
      var TIMECODESCALE_ID = 0x2ad7b1;
      var DURATION_ID = 0x4489;

      var ebml = findElement(bytes, 0, bytes.length, EBML_ID);
      var afterEbml = ebml ? ebml.contentEnd : 0;
      var segment = findElement(bytes, afterEbml, bytes.length, SEGMENT_ID);
      if (!segment) return null;

      var info = findElement(bytes, segment.contentStart, segment.contentEnd, INFO_ID);
      if (!info) return null;

      var timecodeScale = 1000000;
      var tcs = findElement(bytes, info.contentStart, info.contentEnd, TIMECODESCALE_ID);
      if (tcs) {
        var v = 0;
        for (var i = 0; i < tcs.sizeValue; i++) v = v * 256 + bytes[tcs.contentStart + i];
        timecodeScale = v;
      }

      var durationValue = (durationSeconds * 1e9) / timecodeScale;
      var dur = findElement(bytes, info.contentStart, info.contentEnd, DURATION_ID);

      if (dur && (dur.sizeValue === 8 || dur.sizeValue === 4)) {
        var patched = new Uint8Array(bytes);
        writeFloatAt(patched, dur.contentStart, dur.sizeValue, durationValue);
        return patched;
      }
      if (dur) return null; // tamanho inesperado, nao arriscar.

      // Duration ausente: insere um novo elemento (id + tamanho + double)
      // logo no inicio do conteudo de Info.
      var insertion = new Uint8Array(11);
      insertion[0] = 0x44;
      insertion[1] = 0x89;
      insertion[2] = 0x88;
      writeFloatAt(insertion, 3, 8, durationValue);

      var newInfoSize = info.sizeValue + insertion.length;
      var maxForLength = Math.pow(2, 7 * info.sizeLength) - 2;
      if (newInfoSize > maxForLength) return null;

      var newSizeBytes = encodeVintValue(newInfoSize, info.sizeLength);

      var out = new Uint8Array(bytes.length + insertion.length);
      out.set(bytes.subarray(0, info.sizeOffset), 0);
      out.set(newSizeBytes, info.sizeOffset);
      out.set(insertion, info.contentStart);
      out.set(bytes.subarray(info.contentStart), info.contentStart + insertion.length);
      return out;
    } catch (e) {
      console.warn('fixWebmDuration failed', e);
      return null;
    }
  };
})();
