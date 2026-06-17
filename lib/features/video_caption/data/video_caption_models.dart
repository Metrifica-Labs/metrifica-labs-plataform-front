/// Modelos do editor de legenda de vídeo, equivalentes aos tipos do
/// pipeline `meal-video` (src/types.ts). Populados a partir da resposta
/// JSON da API local de transcrição/análise (ver `video_caption_page.dart`).
library;

import 'package:flutter/material.dart';

/// Estilo visual da caixa de legenda sobreposta ao vídeo (fonte, tamanho,
/// cor de fundo e posição), ajustável pelo usuário na aba "Estilo".
class CaptionStyle {
  const CaptionStyle({
    this.fontFamily = 'Syne',
    this.fontSize = 18,
    this.textColor = const Color(0xFFFFFFFF),
    this.backgroundColor = const Color(0xD9000000),
    this.bottomOffset = 52,
    this.maxWidthPercent = 85,
  });

  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  final double bottomOffset;

  /// Largura máxima da caixa de legenda, em % da largura do vídeo —
  /// garante que o texto se ajuste ao quadro em vez de vazar pras bordas.
  final double maxWidthPercent;

  CaptionStyle copyWith({
    String? fontFamily,
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    double? bottomOffset,
    double? maxWidthPercent,
  }) =>
      CaptionStyle(
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        textColor: textColor ?? this.textColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        bottomOffset: bottomOffset ?? this.bottomOffset,
        maxWidthPercent: maxWidthPercent ?? this.maxWidthPercent,
      );
}

double _num(Object? v, [double fallback = 0]) =>
    v == null ? fallback : (v as num).toDouble();

int _int(Object? v, [int fallback = 0]) =>
    v == null ? fallback : (v as num).round();

class Word {
  Word({required this.word, required this.start, required this.end});
  final String word;
  final double start;
  final double end;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        word: json['word'] as String? ?? '',
        start: _num(json['start']),
        end: _num(json['end']),
      );
}

class TranscriptSegment {
  TranscriptSegment({
    required this.id,
    required this.start,
    required this.end,
    required this.text,
  });
  final int id;
  final double start;
  final double end;
  final String text;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) =>
      TranscriptSegment(
        id: _int(json['id']),
        start: _num(json['start']),
        end: _num(json['end']),
        text: json['text'] as String? ?? '',
      );
}

class CaptionWord {
  CaptionWord({
    required this.word,
    required this.startFrame,
    required this.endFrame,
  });
  final String word;
  final int startFrame;
  final int endFrame;

  factory CaptionWord.fromJson(Map<String, dynamic> json) => CaptionWord(
        word: json['word'] as String? ?? '',
        startFrame: _int(json['startFrame']),
        endFrame: _int(json['endFrame']),
      );
}

/// Mutável: editado pelo usuário arrastando handles na timeline.
class Cut {
  Cut({required this.start, required this.end, required this.reason});
  double start;
  double end;
  String reason;

  factory Cut.fromJson(Map<String, dynamic> json) => Cut(
        start: _num(json['start']),
        end: _num(json['end']),
        reason: json['reason'] as String? ?? '',
      );
}

/// Mutável: texto editado pelo usuário no painel de legendas.
class Caption {
  Caption({
    required this.startFrame,
    required this.endFrame,
    required this.text,
    this.words,
  });
  final int startFrame;
  final int endFrame;
  String text;
  /// Timing palavra-a-palavra para o highlight estilo karaokê. Invalidado
  /// (setado para null) quando o usuário edita [text] manualmente, já que
  /// os tempos antigos deixam de corresponder ao novo texto.
  List<CaptionWord>? words;

  factory Caption.fromJson(Map<String, dynamic> json) => Caption(
        startFrame: _int(json['startFrame']),
        endFrame: _int(json['endFrame']),
        text: json['text'] as String? ?? '',
        words: (json['words'] as List?)
            ?.map((w) => CaptionWord.fromJson(w as Map<String, dynamic>))
            .toList(),
      );
}

class VideoEdit {
  VideoEdit({
    required this.id,
    required this.videoFileName,
    required this.durationSeconds,
    required this.fps,
    required this.transcript,
    required this.cuts,
    required this.captions,
    required this.analysisNotes,
    this.rotation = 0,
  });

  factory VideoEdit.fromJson(Map<String, dynamic> json) => VideoEdit(
        id: json['id'] as String? ?? '',
        videoFileName: json['videoFileName'] as String? ?? '',
        durationSeconds: _num(json['durationSeconds']),
        fps: _int(json['fps'], 30),
        transcript: (json['transcript'] as List? ?? [])
            .map((t) => TranscriptSegment.fromJson(t as Map<String, dynamic>))
            .toList(),
        cuts: (json['cuts'] as List? ?? [])
            .map((c) => Cut.fromJson(c as Map<String, dynamic>))
            .toList(),
        captions: (json['captions'] as List? ?? [])
            .map((c) => Caption.fromJson(c as Map<String, dynamic>))
            .toList(),
        analysisNotes: json['analysisNotes'] as String? ?? '',
        rotation: _int(json['rotation'], 0),
      );

  final String id;
  final String videoFileName;
  final double durationSeconds;
  final int fps;
  final List<TranscriptSegment> transcript;
  final List<Cut> cuts;
  final List<Caption> captions;
  final String analysisNotes;
  int rotation;
}

/// Calcula os trechos "mantidos" (fora dos cortes), igual a getKeeps() no JS.
class KeepSegment {
  KeepSegment(this.start, this.end);
  final double start;
  final double end;
}

List<KeepSegment> computeKeepSegments(VideoEdit edit) {
  final sorted = [...edit.cuts]..sort((a, b) => a.start.compareTo(b.start));
  final keeps = <KeepSegment>[];
  var cursor = 0.0;
  for (final c in sorted) {
    if (c.start > cursor + 0.05) keeps.add(KeepSegment(cursor, c.start));
    cursor = c.end;
  }
  if (cursor < edit.durationSeconds - 0.05) {
    keeps.add(KeepSegment(cursor, edit.durationSeconds));
  }
  return keeps;
}

/// Trecho com fala (segmento de transcrição) que não está coberto por
/// nenhuma legenda — geralmente porque a análise de IA pulou aquelas
/// palavras ao agrupar as legendas.
class CaptionGap {
  CaptionGap(this.start, this.end);
  final double start;
  final double end;
}

/// Varre cada segmento de transcrição e devolve os sub-trechos não cobertos
/// por nenhuma legenda existente (com folga mínima [minGapSeconds] para
/// ignorar lacunas insignificantes de arredondamento).
List<CaptionGap> findCaptionGaps(VideoEdit edit, {double minGapSeconds = 0.5}) {
  if (edit.transcript.isEmpty) return [];

  final capRanges = edit.captions
      .map((c) => (c.startFrame / edit.fps, c.endFrame / edit.fps))
      .toList()
    ..sort((a, b) => a.$1.compareTo(b.$1));

  final gaps = <CaptionGap>[];
  for (final seg in edit.transcript) {
    var cursor = seg.start;
    for (final cap in capRanges) {
      if (cap.$2 <= cursor) continue;
      if (cap.$1 >= seg.end) break;
      if (cap.$1 > cursor) {
        final gapEnd = cap.$1.clamp(cursor, seg.end);
        if (gapEnd - cursor >= minGapSeconds) gaps.add(CaptionGap(cursor, gapEnd));
      }
      if (cap.$2 > cursor) cursor = cap.$2;
      if (cursor >= seg.end) break;
    }
    if (cursor < seg.end - 0.001 && seg.end - cursor >= minGapSeconds) {
      gaps.add(CaptionGap(cursor, seg.end));
    }
  }
  return gaps;
}

String fmtTime(double seconds) {
  final t = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
  final m = t ~/ 60;
  final s = t % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String fmtDuration(double seconds) {
  final t = seconds.isFinite ? seconds.round() : 0;
  if (t >= 60) return '${t ~/ 60}m ${t % 60}s';
  return '${t}s';
}

double? parseTimeInput(String raw) {
  final str = raw.trim();
  if (str.contains(':')) {
    final parts = str.split(':');
    if (parts.length != 2) return null;
    final m = double.tryParse(parts[0]);
    final s = double.tryParse(parts[1]);
    if (m == null || s == null) return null;
    return m * 60 + s;
  }
  return double.tryParse(str);
}

