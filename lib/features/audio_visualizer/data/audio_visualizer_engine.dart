import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'audio_visualizer_config.dart';
import 'captions.dart';

/// Corrige a duracao do .webm gravado (ver web/webm_duration_fix.js).
/// Retorna null se nao for possivel aplicar a correcao com seguranca.
@JS('fixWebmDuration')
external JSUint8Array? _jsFixWebmDuration(
    JSUint8Array bytes, JSNumber durationSeconds);

/// Estado do motor exposto para a UI.
enum VizPlaybackState { idle, playing, paused }

/// Motor que renderiza o audio visualizer num `<canvas>` HTML usando a
/// Web Audio API e grava o resultado (canvas + audio) em .webm via
/// MediaRecorder. Tudo client-side, sem backend.
///
/// O mesmo canvas e usado para o preview ao vivo (embutido no Flutter via
/// HtmlElementView) e para a gravacao.
class AudioVisualizerEngine {
  AudioVisualizerEngine() {
    viewType = 'audio-visualizer-canvas-${_instanceCounter++}';
    _canvas = (web.document.createElement('canvas') as web.HTMLCanvasElement)
      ..width = _config.aspect.width
      ..height = _config.aspect.height;
    _canvas.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..display = 'block';
    _ctx = _canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ui_web.platformViewRegistry
        .registerViewFactory(viewType, (int _) => _canvas);
  }

  static int _instanceCounter = 0;
  late final String viewType;

  late final web.HTMLCanvasElement _canvas;
  late final web.CanvasRenderingContext2D _ctx;

  AudioVisualizerConfig _config = const AudioVisualizerConfig();
  Captions _captions = const Captions(segments: [], words: []);

  // Web Audio
  web.AudioContext? _audioCtx;
  web.HTMLAudioElement? _audioEl;
  web.AnalyserNode? _analyser;
  web.MediaStreamAudioDestinationNode? _streamDest;
  JSUint8Array? _freqBuffer;
  String? _audioUrl;

  // Imagens
  web.HTMLImageElement? _centerImg;
  web.HTMLImageElement? _bgImg;

  // Loop de render
  int _rafId = 0;
  bool _looping = false;
  double _rotation = 0;
  double _lastFrameMs = 0;
  double _pulse = 0;

  // Gravacao
  web.MediaRecorder? _recorder;
  final List<web.Blob> _chunks = [];
  bool _recording = false;

  // Callbacks para a UI
  void Function(VizPlaybackState state)? onStateChanged;
  void Function(double current, double total)? onProgress;
  void Function(bool recording)? onRecordingChanged;
  void Function(Uint8List bytes, String mimeType)? onExportReady;

  bool get hasAudio => _audioEl != null;
  bool get isRecording => _recording;
  double get duration => _audioEl?.duration.isFinite == true
      ? _audioEl!.duration.toDouble()
      : 0.0;

  // ---------------------------------------------------------------------------
  // Configuracao / assets
  // ---------------------------------------------------------------------------

  void updateConfig(AudioVisualizerConfig config) {
    final aspectChanged = config.aspect != _config.aspect;
    _config = config;
    if (aspectChanged) {
      _canvas
        ..width = config.aspect.width
        ..height = config.aspect.height;
    }
    if (!_looping) _renderOnce();
  }

  Future<void> setCenterImage(Uint8List? bytes) async {
    _centerImg = await _loadImage(bytes);
    if (!_looping) _renderOnce();
  }

  Future<void> setBackgroundImage(Uint8List? bytes) async {
    _bgImg = await _loadImage(bytes);
    if (!_looping) _renderOnce();
  }

  void setCaptions(Captions captions) {
    _captions = captions;
    if (!_looping) _renderOnce();
  }

  Future<web.HTMLImageElement?> _loadImage(Uint8List? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/*'),
    );
    final url = web.URL.createObjectURL(blob);
    final img = web.HTMLImageElement();
    final completer = Completer<web.HTMLImageElement?>();
    img.addEventListener(
        'load',
        ((web.Event _) {
          if (!completer.isCompleted) completer.complete(img);
        }).toJS);
    img.addEventListener(
        'error',
        ((web.Event _) {
          if (!completer.isCompleted) completer.complete(null);
        }).toJS);
    img.src = url;
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Audio
  // ---------------------------------------------------------------------------

  Future<void> loadAudio(Uint8List bytes, {String mime = 'audio/mpeg'}) async {
    await stop();
    _disposeAudio();

    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    _audioUrl = web.URL.createObjectURL(blob);

    final ctx = web.AudioContext();
    final audioEl = web.HTMLAudioElement()
      ..src = _audioUrl!
      ..crossOrigin = 'anonymous'
      ..preload = 'auto';

    final srcNode = ctx.createMediaElementSource(audioEl);
    final analyser = ctx.createAnalyser()
      ..fftSize = 512
      ..smoothingTimeConstant = 0.8;
    final streamDest = ctx.createMediaStreamDestination();

    srcNode.connect(analyser);
    analyser.connect(ctx.destination);
    srcNode.connect(streamDest);

    audioEl.addEventListener('timeupdate', (_onTimeUpdate).toJS);
    audioEl.addEventListener('ended', (_onEnded).toJS);
    audioEl.addEventListener('play', (_onPlay).toJS);
    audioEl.addEventListener('pause', (_onPause).toJS);

    _audioCtx = ctx;
    _audioEl = audioEl;
    _analyser = analyser;
    _streamDest = streamDest;
    _freqBuffer = Uint8List(analyser.frequencyBinCount).toJS;

    // Aguarda metadados para ter a duracao.
    final completer = Completer<void>();
    audioEl.addEventListener(
        'loadedmetadata',
        ((web.Event _) {
          if (!completer.isCompleted) completer.complete();
        }).toJS);
    await completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () {});

    _startLoop();
    onProgress?.call(0, duration);
  }

  void _onTimeUpdate(web.Event _) {
    onProgress?.call(_audioEl?.currentTime.toDouble() ?? 0, duration);
  }

  void _onPlay(web.Event _) => onStateChanged?.call(VizPlaybackState.playing);
  void _onPause(web.Event _) {
    if (!_recording) onStateChanged?.call(VizPlaybackState.paused);
  }

  void _onEnded(web.Event _) {
    onStateChanged?.call(VizPlaybackState.idle);
    if (_recording) _finishRecording();
  }

  Future<void> play() async {
    final ctx = _audioCtx;
    if (ctx != null && ctx.state == 'suspended') {
      await ctx.resume().toDart;
    }
    await _audioEl?.play().toDart;
  }

  void pause() => _audioEl?.pause();

  Future<void> stop() async {
    _audioEl?.pause();
    if (_audioEl != null) _audioEl!.currentTime = 0;
    onStateChanged?.call(VizPlaybackState.idle);
  }

  void seek(double seconds) {
    if (_audioEl != null) _audioEl!.currentTime = seconds;
  }

  // ---------------------------------------------------------------------------
  // Gravacao -> .webm
  // ---------------------------------------------------------------------------

  Future<void> startExport() async {
    if (_audioEl == null || _streamDest == null || _recording) return;

    final mime = _pickMimeType();
    final canvasStream = _canvas.captureStream(_config.fps.toDouble());
    final combined = web.MediaStream();
    for (final t in canvasStream.getVideoTracks().toDart) {
      combined.addTrack(t);
    }
    for (final t in _streamDest!.stream.getAudioTracks().toDart) {
      combined.addTrack(t);
    }

    _chunks.clear();
    final recorder = web.MediaRecorder(
      combined,
      web.MediaRecorderOptions(
        mimeType: mime,
        videoBitsPerSecond: 8000000,
      ),
    );
    recorder.addEventListener('dataavailable', (_onDataAvailable).toJS);
    recorder.addEventListener('stop', (_onRecorderStop).toJS);
    _recorder = recorder;
    _exportMime = mime;

    // Reinicia o audio do zero e grava do comeco ao fim.
    final ctx = _audioCtx;
    if (ctx != null && ctx.state == 'suspended') {
      await ctx.resume().toDart;
    }
    _audioEl!.currentTime = 0;
    recorder.start(100); // coleta chunks a cada 100ms
    _recording = true;
    onRecordingChanged?.call(true);
    onStateChanged?.call(VizPlaybackState.playing);
    await _audioEl!.play().toDart;
  }

  void cancelExport() {
    if (!_recording) return;
    _recording = false;
    _audioEl?.pause();
    try {
      _recorder?.stop();
    } catch (_) {}
    _recorder = null;
    _chunks.clear();
    onRecordingChanged?.call(false);
    onStateChanged?.call(VizPlaybackState.idle);
  }

  String _exportMime = 'video/webm';

  void _onDataAvailable(web.Event e) {
    final blob = (e as web.BlobEvent).data;
    if (blob.size > 0) _chunks.add(blob);
  }

  void _finishRecording() {
    if (!_recording) return;
    try {
      _recorder?.stop();
    } catch (_) {}
  }

  void _onRecorderStop(web.Event _) {
    _recording = false;
    onRecordingChanged?.call(false);
    onStateChanged?.call(VizPlaybackState.idle);

    final recordedDuration = duration;
    final blob = web.Blob(
      _chunks.map((c) => c as JSAny).toList().toJS,
      web.BlobPropertyBag(type: _exportMime),
    );
    final reader = web.FileReader();
    reader.addEventListener(
        'load',
        ((web.Event _) {
          final result = reader.result;
          if (result != null && result.isA<JSArrayBuffer>()) {
            final buffer = (result as JSArrayBuffer).toDart;
            var bytes = buffer.asUint8List();
            if (recordedDuration > 0) {
              try {
                final fixed =
                    _jsFixWebmDuration(bytes.toJS, recordedDuration.toJS);
                if (fixed != null) bytes = fixed.toDart;
              } catch (_) {
                // Mantem os bytes originais se a correcao falhar.
              }
            }
            onExportReady?.call(bytes, _exportMime);
          }
        }).toJS);
    reader.readAsArrayBuffer(blob);
    _recorder = null;
  }

  String _pickMimeType() {
    const candidates = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm',
    ];
    for (final c in candidates) {
      if (web.MediaRecorder.isTypeSupported(c)) return c;
    }
    return 'video/webm';
  }

  // ---------------------------------------------------------------------------
  // Render loop
  // ---------------------------------------------------------------------------

  void _startLoop() {
    if (_looping) return;
    _looping = true;
    _lastFrameMs = 0;
    _rafId = web.window.requestAnimationFrame((_frame).toJS);
  }

  void _frame(double tMs) {
    final dt = _lastFrameMs == 0 ? 0.016 : (tMs - _lastFrameMs) / 1000.0;
    _lastFrameMs = tMs;
    _rotation += _config.rotationSpeed * dt;
    _renderOnce(dt: dt);
    if (_looping) {
      _rafId = web.window.requestAnimationFrame((_frame).toJS);
    }
  }

  void _renderOnce({double dt = 0.016}) {
    final w = _config.aspect.width.toDouble();
    final h = _config.aspect.height.toDouble();
    final ctx = _ctx;

    _drawBackground(ctx, w, h);

    // Dados de frequencia.
    final freq = _readFrequency();
    final cx = w / 2;
    final cy = h / 2;
    final minSide = math.min(w, h);
    final radius = minSide * _config.ringRadius;

    // Pulso (media de amplitude) suavizado.
    double avg = 0;
    if (freq.isNotEmpty) {
      var sum = 0;
      for (final v in freq) {
        sum += v;
      }
      avg = sum / freq.length / 255.0;
    }
    _pulse += (avg - _pulse) * math.min(1.0, dt * 8);

    _drawCenterImage(ctx, cx, cy, radius);
    _drawRing(ctx, freq, cx, cy, radius);
    if (_config.captionEnabled) _drawCaption(ctx, w, h);
  }

  List<int> _readFrequency() {
    final analyser = _analyser;
    final buffer = _freqBuffer;
    if (analyser == null || buffer == null) {
      // Idle: gera uma onda suave para o preview sem audio.
      final n = _config.barCount;
      final t = _lastFrameMs / 1000.0;
      return List<int>.generate(n, (i) {
        final v = (math.sin(i * 0.4 + t * 2) + 1) / 2;
        return (v * 60 + 10).round();
      });
    }
    analyser.getByteFrequencyData(buffer);
    return buffer.toDart;
  }

  void _drawBackground(web.CanvasRenderingContext2D ctx, double w, double h) {
    switch (_config.backgroundType) {
      case BackgroundType.solid:
        ctx.fillStyle = _css(_config.backgroundColor).toJS;
        ctx.fillRect(0, 0, w, h);
        break;
      case BackgroundType.gradient:
        final g = ctx.createLinearGradient(0, 0, w, h);
        g.addColorStop(0, _css(_config.backgroundColor));
        g.addColorStop(1, _css(_config.backgroundColor2));
        ctx.fillStyle = g;
        ctx.fillRect(0, 0, w, h);
        break;
      case BackgroundType.image:
        ctx.fillStyle = _css(_config.backgroundColor).toJS;
        ctx.fillRect(0, 0, w, h);
        final img = _bgImg;
        if (img != null) {
          _drawCover(ctx, img, 0, 0, w, h);
        }
        break;
    }
  }

  void _drawRing(
    web.CanvasRenderingContext2D ctx,
    List<int> freq,
    double cx,
    double cy,
    double radius,
  ) {
    final n = _config.barCount;
    if (n <= 0 || freq.isEmpty) return;

    final scaleX = _config.aspect.width / 1080.0;
    final barW = _config.barWidth * scaleX;
    final maxLen = _config.barMaxLength * scaleX;

    final grad = ctx.createLinearGradient(0, -maxLen, 0, 0);
    grad.addColorStop(0, _css(_config.ringColorEnd));
    grad.addColorStop(1, _css(_config.ringColorStart));

    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(_rotation * math.pi / 180);

    if (_config.glow) {
      ctx.shadowColor = _css(_config.ringColorStart);
      ctx.shadowBlur = 16 * scaleX;
    }

    // Usa metade do espectro e espelha para ficar simetrico.
    final half = (n / 2).ceil();
    for (var i = 0; i < n; i++) {
      final mirrored = i < half ? i : n - i;
      final bin = (mirrored / half * (freq.length * 0.7)).floor();
      final amp = (freq[bin.clamp(0, freq.length - 1)] / 255.0) *
          _config.sensitivity;
      final len = (amp * maxLen).clamp(2.0, maxLen);

      final angle = (i / n) * 2 * math.pi;
      ctx.save();
      ctx.rotate(angle);
      ctx.fillStyle = grad;
      ctx.fillRect(-barW / 2, -radius - len, barW, len);
      ctx.restore();
    }
    ctx.restore();
    ctx.shadowBlur = 0;
  }

  void _drawCenterImage(
    web.CanvasRenderingContext2D ctx,
    double cx,
    double cy,
    double radius,
  ) {
    final img = _centerImg;
    final pulse = _config.centerImagePulse ? (1 + _pulse * 0.12) : 1.0;
    final innerR = radius * _config.centerImageScale * pulse;

    if (img == null) {
      // Placeholder sutil quando nao ha imagem central.
      ctx.beginPath();
      ctx.arc(cx, cy, innerR, 0, 2 * math.pi);
      ctx.fillStyle = 'rgba(255,255,255,0.04)'.toJS;
      ctx.fill();
      return;
    }

    final size = innerR * 2;
    final dx = cx - innerR;
    final dy = cy - innerR;

    ctx.save();
    if (_config.centerImageCircular) {
      ctx.beginPath();
      ctx.arc(cx, cy, innerR, 0, 2 * math.pi);
      ctx.clip();
    }
    _drawCover(ctx, img, dx, dy, size, size);
    ctx.restore();
  }

  /// Desenha [img] cobrindo a area (object-fit: cover) sem distorcer.
  void _drawCover(
    web.CanvasRenderingContext2D ctx,
    web.HTMLImageElement img,
    double dx,
    double dy,
    double dw,
    double dh,
  ) {
    final iw = img.naturalWidth.toDouble();
    final ih = img.naturalHeight.toDouble();
    if (iw == 0 || ih == 0) return;
    final scale = math.max(dw / iw, dh / ih);
    final sw = dw / scale;
    final sh = dh / scale;
    final sx = (iw - sw) / 2;
    final sy = (ih - sh) / 2;
    ctx.drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh);
  }

  // ---------------------------------------------------------------------------
  // Legenda
  // ---------------------------------------------------------------------------

  void _drawCaption(web.CanvasRenderingContext2D ctx, double w, double h) {
    if (_captions.isEmpty) return;
    final t = _audioEl?.currentTime.toDouble() ?? 0;
    final scaleX = _config.aspect.width / 1080.0;
    final fontSize = _config.captionFontSize * scaleX;
    final weight = _config.captionBold ? '700' : '500';
    ctx.font = '$weight ${fontSize.toStringAsFixed(0)}px Arial, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    final baseY = h * (1 - _config.captionBottomOffset);

    if (_config.captionShadow) {
      ctx.shadowColor = 'rgba(0,0,0,0.7)';
      ctx.shadowBlur = 8 * scaleX;
    }

    switch (_config.captionMode) {
      case CaptionMode.word:
        final word = _currentWord(t);
        if (word != null) {
          ctx.fillStyle = _css(_config.captionHighlightColor).toJS;
          ctx.fillText(word.word, w / 2, baseY);
        }
        break;
      case CaptionMode.segment:
        final seg = _currentSegment(t);
        if (seg != null) {
          ctx.fillStyle = _css(_config.captionColor).toJS;
          _fillWrapped(ctx, seg.text, w / 2, baseY, w * 0.86, fontSize * 1.25);
        }
        break;
      case CaptionMode.karaoke:
        _drawKaraoke(ctx, t, w, baseY, fontSize, scaleX);
        break;
    }
    ctx.shadowBlur = 0;
  }

  void _drawKaraoke(
    web.CanvasRenderingContext2D ctx,
    double t,
    double w,
    double baseY,
    double fontSize,
    double scaleX,
  ) {
    // Janela de palavras ao redor da palavra atual.
    final words = _captions.words;
    if (words.isEmpty) {
      final seg = _currentSegment(t);
      if (seg != null) {
        ctx.fillStyle = _css(_config.captionColor).toJS;
        _fillWrapped(ctx, seg.text, w / 2, baseY, w * 0.86, fontSize * 1.25);
      }
      return;
    }

    var activeIdx = -1;
    for (var i = 0; i < words.length; i++) {
      if (t >= words[i].start && t <= words[i].end) {
        activeIdx = i;
        break;
      }
      if (t < words[i].start) {
        activeIdx = i - 1;
        break;
      }
      activeIdx = i;
    }

    final maxWords = _config.captionMaxWords.clamp(1, 12);
    final groupStart = activeIdx < 0
        ? 0
        : (activeIdx ~/ maxWords) * maxWords;
    final groupEnd = math.min(groupStart + maxWords, words.length);
    final group = words.sublist(groupStart.clamp(0, words.length), groupEnd);
    if (group.isEmpty) return;

    final gap = fontSize * 0.32;
    var total = 0.0;
    final widths = <double>[];
    for (final word in group) {
      final m = ctx.measureText('${word.word} ');
      widths.add(m.width + gap);
      total += m.width + gap;
    }
    var x = w / 2 - total / 2;
    ctx.textAlign = 'left';
    for (var i = 0; i < group.length; i++) {
      final word = group[i];
      final isActive = (groupStart + i) == activeIdx;
      ctx.fillStyle = (isActive
              ? _css(_config.captionHighlightColor)
              : _css(_config.captionColor))
          .toJS;
      ctx.fillText('${word.word} ', x, baseY);
      x += widths[i];
    }
    ctx.textAlign = 'center';
  }

  void _fillWrapped(
    web.CanvasRenderingContext2D ctx,
    String text,
    double cx,
    double baseY,
    double maxWidth,
    double lineHeight,
  ) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      final test = current.isEmpty ? word : '$current $word';
      if (ctx.measureText(test).width > maxWidth && current.isNotEmpty) {
        lines.add(current);
        current = word;
      } else {
        current = test;
      }
    }
    if (current.isNotEmpty) lines.add(current);

    final startY = baseY - (lines.length - 1) * lineHeight / 2;
    for (var i = 0; i < lines.length; i++) {
      ctx.fillText(lines[i], cx, startY + i * lineHeight);
    }
  }

  CaptionWord? _currentWord(double t) {
    for (final w in _captions.words) {
      if (t >= w.start && t <= w.end) return w;
    }
    // Mantem a ultima palavra ja iniciada (evita "buracos").
    CaptionWord? last;
    for (final w in _captions.words) {
      if (t >= w.start) last = w;
    }
    return last;
  }

  CaptionSegment? _currentSegment(double t) {
    for (final s in _captions.segments) {
      if (t >= s.start && t <= s.end) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Util
  // ---------------------------------------------------------------------------

  String _css(Color c) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return 'rgba(${ch(c.r)},${ch(c.g)},${ch(c.b)},${c.a})';
  }

  void _disposeAudio() {
    if (_audioUrl != null) {
      web.URL.revokeObjectURL(_audioUrl!);
      _audioUrl = null;
    }
    try {
      _audioCtx?.close();
    } catch (_) {}
    _audioCtx = null;
    _audioEl = null;
    _analyser = null;
    _streamDest = null;
    _freqBuffer = null;
  }

  void dispose() {
    _looping = false;
    if (_rafId != 0) web.window.cancelAnimationFrame(_rafId);
    cancelExport();
    _disposeAudio();
  }
}
