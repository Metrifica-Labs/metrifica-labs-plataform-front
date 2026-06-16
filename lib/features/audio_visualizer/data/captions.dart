import 'dart:convert';

/// Uma palavra com timestamps (formato gerado por scripts/transcribe.py).
class CaptionWord {
  final String word;
  final double start;
  final double end;

  const CaptionWord({
    required this.word,
    required this.start,
    required this.end,
  });
}

/// Um segmento (frase) com suas palavras.
class CaptionSegment {
  final double start;
  final double end;
  final String text;
  final List<CaptionWord> words;

  const CaptionSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.words,
  });
}

/// Conjunto de legendas sincronizadas com o audio.
class Captions {
  final List<CaptionSegment> segments;
  final List<CaptionWord> words;

  const Captions({required this.segments, required this.words});

  bool get isEmpty => segments.isEmpty && words.isEmpty;

  /// Aceita:
  ///  - JSON gerado por scripts/transcribe.py ({ segments, words })
  ///  - SRT / WebVTT simples (fallback, sem timestamps por palavra)
  static Captions parse(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return const Captions(segments: [], words: []);
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return _parseJson(trimmed);
    }
    return _parseSrt(trimmed);
  }

  static Captions _parseJson(String content) {
    final decoded = jsonDecode(content);
    final Map<String, dynamic> map =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    final segments = <CaptionSegment>[];
    final words = <CaptionWord>[];

    final rawSegments = map['segments'];
    if (rawSegments is List) {
      for (final s in rawSegments) {
        if (s is! Map) continue;
        final segWords = <CaptionWord>[];
        final rawWords = s['words'];
        if (rawWords is List) {
          for (final w in rawWords) {
            if (w is! Map) continue;
            final word = CaptionWord(
              word: (w['word'] ?? '').toString().trim(),
              start: _toDouble(w['start']),
              end: _toDouble(w['end']),
            );
            if (word.word.isEmpty) continue;
            segWords.add(word);
            words.add(word);
          }
        }
        segments.add(CaptionSegment(
          start: _toDouble(s['start']),
          end: _toDouble(s['end']),
          text: (s['text'] ?? '').toString().trim(),
          words: segWords,
        ));
      }
    }

    // Caso so venha a lista plana de words.
    final rawWords = map['words'];
    if (words.isEmpty && rawWords is List) {
      for (final w in rawWords) {
        if (w is! Map) continue;
        final word = CaptionWord(
          word: (w['word'] ?? '').toString().trim(),
          start: _toDouble(w['start']),
          end: _toDouble(w['end']),
        );
        if (word.word.isEmpty) continue;
        words.add(word);
      }
    }

    return Captions(segments: segments, words: words);
  }

  static final _srtTime = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );

  static Captions _parseSrt(String content) {
    final segments = <CaptionSegment>[];
    final words = <CaptionWord>[];
    final blocks = content.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final match = _srtTime.firstMatch(block);
      if (match == null) continue;
      final start = _srtToSeconds(match, 1);
      final end = _srtToSeconds(match, 5);
      final lines = block.split('\n');
      final textLines = <String>[];
      for (final line in lines) {
        if (_srtTime.hasMatch(line)) continue;
        if (RegExp(r'^\d+$').hasMatch(line.trim())) continue;
        if (line.trim().toUpperCase() == 'WEBVTT') continue;
        if (line.trim().isEmpty) continue;
        textLines.add(line.trim());
      }
      final text = textLines.join(' ').trim();
      if (text.isEmpty) continue;
      segments.add(CaptionSegment(
        start: start,
        end: end,
        text: text,
        words: const [],
      ));
      words.add(CaptionWord(word: text, start: start, end: end));
    }

    return Captions(segments: segments, words: words);
  }

  static double _srtToSeconds(RegExpMatch m, int offset) {
    final h = int.parse(m.group(offset)!);
    final min = int.parse(m.group(offset + 1)!);
    final s = int.parse(m.group(offset + 2)!);
    final ms = int.parse(m.group(offset + 3)!.padRight(3, '0'));
    return h * 3600 + min * 60 + s + ms / 1000.0;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
