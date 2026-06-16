import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Proporcao/resolucao do video exportado.
enum VideoAspect {
  square('Quadrado (1080x1080)', 1080, 1080),
  portrait('Vertical (1080x1920)', 1080, 1920),
  story('Story (1080x1920)', 1080, 1920),
  landscape('Horizontal (1920x1080)', 1920, 1080);

  const VideoAspect(this.label, this.width, this.height);
  final String label;
  final int width;
  final int height;
}

/// Tipo de fundo atras do visualizer.
enum BackgroundType { solid, gradient, image }

/// Como a legenda destaca o tempo atual.
enum CaptionMode {
  /// Mostra a frase inteira do segmento atual.
  segment('Frase completa'),

  /// Karaoke: destaca a palavra atual dentro da frase.
  karaoke('Karaoke (palavra)'),

  /// Mostra apenas a palavra atual, grande e centralizada.
  word('Palavra por palavra');

  const CaptionMode(this.label);
  final String label;
}

/// Configuracao completa do Audio Visualizer. Imutavel + copyWith.
@immutable
class AudioVisualizerConfig {
  // Canvas / video
  final VideoAspect aspect;
  final int fps;

  // Anel (espectro circular)
  final Color ringColorStart;
  final Color ringColorEnd;
  final int barCount;
  final double ringRadius; // fracao do menor lado (0..1)
  final double barWidth; // px logicos no canvas base
  final double barMaxLength; // px logicos
  final double sensitivity; // multiplicador de amplitude
  final double rotationSpeed; // graus por segundo
  final bool glow;

  // Imagem central
  final Uint8List? centerImageBytes;
  final double centerImageScale; // fracao do diametro interno (0..1)
  final bool centerImageCircular;
  final bool centerImagePulse; // pulsa com o audio

  // Fundo
  final BackgroundType backgroundType;
  final Color backgroundColor;
  final Color backgroundColor2;
  final Uint8List? backgroundImageBytes;

  // Legenda
  final bool captionEnabled;
  final CaptionMode captionMode;
  final double captionFontSize; // px logicos
  final Color captionColor;
  final Color captionHighlightColor;
  final double captionBottomOffset; // fracao da altura (0..1) a partir de baixo
  final int captionMaxWords; // palavras por linha no modo karaoke
  final bool captionShadow;
  final bool captionBold;

  const AudioVisualizerConfig({
    this.aspect = VideoAspect.square,
    this.fps = 30,
    this.ringColorStart = const Color(0xFFEC4899),
    this.ringColorEnd = const Color(0xFF6366F1),
    this.barCount = 96,
    this.ringRadius = 0.30,
    this.barWidth = 5,
    this.barMaxLength = 120,
    this.sensitivity = 1.0,
    this.rotationSpeed = 6,
    this.glow = true,
    this.centerImageBytes,
    this.centerImageScale = 0.85,
    this.centerImageCircular = true,
    this.centerImagePulse = true,
    this.backgroundType = BackgroundType.solid,
    this.backgroundColor = const Color(0xFF05050A),
    this.backgroundColor2 = const Color(0xFF1A1033),
    this.backgroundImageBytes,
    this.captionEnabled = true,
    this.captionMode = CaptionMode.karaoke,
    this.captionFontSize = 48,
    this.captionColor = const Color(0xCCFFFFFF),
    this.captionHighlightColor = const Color(0xFFFFFFFF),
    this.captionBottomOffset = 0.16,
    this.captionMaxWords = 5,
    this.captionShadow = true,
    this.captionBold = true,
  });

  AudioVisualizerConfig copyWith({
    VideoAspect? aspect,
    int? fps,
    Color? ringColorStart,
    Color? ringColorEnd,
    int? barCount,
    double? ringRadius,
    double? barWidth,
    double? barMaxLength,
    double? sensitivity,
    double? rotationSpeed,
    bool? glow,
    Object? centerImageBytes = _sentinel,
    double? centerImageScale,
    bool? centerImageCircular,
    bool? centerImagePulse,
    BackgroundType? backgroundType,
    Color? backgroundColor,
    Color? backgroundColor2,
    Object? backgroundImageBytes = _sentinel,
    bool? captionEnabled,
    CaptionMode? captionMode,
    double? captionFontSize,
    Color? captionColor,
    Color? captionHighlightColor,
    double? captionBottomOffset,
    int? captionMaxWords,
    bool? captionShadow,
    bool? captionBold,
  }) {
    return AudioVisualizerConfig(
      aspect: aspect ?? this.aspect,
      fps: fps ?? this.fps,
      ringColorStart: ringColorStart ?? this.ringColorStart,
      ringColorEnd: ringColorEnd ?? this.ringColorEnd,
      barCount: barCount ?? this.barCount,
      ringRadius: ringRadius ?? this.ringRadius,
      barWidth: barWidth ?? this.barWidth,
      barMaxLength: barMaxLength ?? this.barMaxLength,
      sensitivity: sensitivity ?? this.sensitivity,
      rotationSpeed: rotationSpeed ?? this.rotationSpeed,
      glow: glow ?? this.glow,
      centerImageBytes: centerImageBytes == _sentinel
          ? this.centerImageBytes
          : centerImageBytes as Uint8List?,
      centerImageScale: centerImageScale ?? this.centerImageScale,
      centerImageCircular: centerImageCircular ?? this.centerImageCircular,
      centerImagePulse: centerImagePulse ?? this.centerImagePulse,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundColor2: backgroundColor2 ?? this.backgroundColor2,
      backgroundImageBytes: backgroundImageBytes == _sentinel
          ? this.backgroundImageBytes
          : backgroundImageBytes as Uint8List?,
      captionEnabled: captionEnabled ?? this.captionEnabled,
      captionMode: captionMode ?? this.captionMode,
      captionFontSize: captionFontSize ?? this.captionFontSize,
      captionColor: captionColor ?? this.captionColor,
      captionHighlightColor:
          captionHighlightColor ?? this.captionHighlightColor,
      captionBottomOffset: captionBottomOffset ?? this.captionBottomOffset,
      captionMaxWords: captionMaxWords ?? this.captionMaxWords,
      captionShadow: captionShadow ?? this.captionShadow,
      captionBold: captionBold ?? this.captionBold,
    );
  }

  static const _sentinel = Object();

  /// Serializa as configuracoes (exceto imagens) para salvar como preset.
  Map<String, dynamic> toPresetJson() => {
        'aspect': aspect.name,
        'fps': fps,
        'ringColorStart': ringColorStart.toARGB32(),
        'ringColorEnd': ringColorEnd.toARGB32(),
        'barCount': barCount,
        'ringRadius': ringRadius,
        'barWidth': barWidth,
        'barMaxLength': barMaxLength,
        'sensitivity': sensitivity,
        'rotationSpeed': rotationSpeed,
        'glow': glow,
        'centerImageScale': centerImageScale,
        'centerImageCircular': centerImageCircular,
        'centerImagePulse': centerImagePulse,
        'backgroundType': backgroundType.name,
        'backgroundColor': backgroundColor.toARGB32(),
        'backgroundColor2': backgroundColor2.toARGB32(),
        'captionEnabled': captionEnabled,
        'captionMode': captionMode.name,
        'captionFontSize': captionFontSize,
        'captionColor': captionColor.toARGB32(),
        'captionHighlightColor': captionHighlightColor.toARGB32(),
        'captionBottomOffset': captionBottomOffset,
        'captionMaxWords': captionMaxWords,
        'captionShadow': captionShadow,
        'captionBold': captionBold,
      };

  /// Aplica um preset salvo sobre esta config, mantendo imagens carregadas.
  AudioVisualizerConfig applyPresetJson(Map<String, dynamic> json) {
    double d(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    int i(String key, int fallback) => (json[key] as num?)?.toInt() ?? fallback;
    bool b(String key, bool fallback) => json[key] as bool? ?? fallback;
    Color c(String key, Color fallback) {
      final v = json[key];
      return v is int ? Color(v) : fallback;
    }

    return copyWith(
      aspect: _enumByName(VideoAspect.values, json['aspect']) ?? aspect,
      fps: i('fps', fps),
      ringColorStart: c('ringColorStart', ringColorStart),
      ringColorEnd: c('ringColorEnd', ringColorEnd),
      barCount: i('barCount', barCount),
      ringRadius: d('ringRadius', ringRadius),
      barWidth: d('barWidth', barWidth),
      barMaxLength: d('barMaxLength', barMaxLength),
      sensitivity: d('sensitivity', sensitivity),
      rotationSpeed: d('rotationSpeed', rotationSpeed),
      glow: b('glow', glow),
      centerImageScale: d('centerImageScale', centerImageScale),
      centerImageCircular: b('centerImageCircular', centerImageCircular),
      centerImagePulse: b('centerImagePulse', centerImagePulse),
      backgroundType:
          _enumByName(BackgroundType.values, json['backgroundType']) ??
              backgroundType,
      backgroundColor: c('backgroundColor', backgroundColor),
      backgroundColor2: c('backgroundColor2', backgroundColor2),
      captionEnabled: b('captionEnabled', captionEnabled),
      captionMode:
          _enumByName(CaptionMode.values, json['captionMode']) ?? captionMode,
      captionFontSize: d('captionFontSize', captionFontSize),
      captionColor: c('captionColor', captionColor),
      captionHighlightColor: c('captionHighlightColor', captionHighlightColor),
      captionBottomOffset: d('captionBottomOffset', captionBottomOffset),
      captionMaxWords: i('captionMaxWords', captionMaxWords),
      captionShadow: b('captionShadow', captionShadow),
      captionBold: b('captionBold', captionBold),
    );
  }
}

T? _enumByName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
