import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Embrulha um `<video>` HTML para uso via HtmlElementView, espelhando o
/// elemento `#mainVideo` do meal-video (public/index.html).
class VideoPreviewEngine {
  VideoPreviewEngine() {
    viewType = 'video-caption-player-${_instanceCounter++}';
    _video = web.document.createElement('video') as web.HTMLVideoElement;
    _video
      ..playsInline = true
      ..controls = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.transition = 'transform .3s ease';
    _video.onTimeUpdate.listen((_) => onTimeUpdate?.call(currentTime));
    _video.onLoadedMetadata.listen((_) => onLoadedMetadata?.call(duration));
    _video.onPlay.listen((_) => onPlayStateChanged?.call(true));
    _video.onPause.listen((_) => onPlayStateChanged?.call(false));
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) => _video);
  }

  static int _instanceCounter = 0;
  late final String viewType;
  late final web.HTMLVideoElement _video;
  String? _objectUrl;

  void Function(double currentTime)? onTimeUpdate;
  void Function(double duration)? onLoadedMetadata;
  void Function(bool playing)? onPlayStateChanged;

  double get currentTime => _video.currentTime.isFinite ? _video.currentTime : 0;
  double get duration => _video.duration.isFinite ? _video.duration : 0;
  bool get paused => _video.paused;

  /// Resolução intrínseca do arquivo de vídeo (não a caixa exibida em tela)
  /// — usada para calcular a área real renderizada sob object-fit: contain.
  int get videoWidth => _video.videoWidth;
  int get videoHeight => _video.videoHeight;

  void load(Uint8List bytes, {String mime = 'video/mp4'}) {
    if (_objectUrl != null) web.URL.revokeObjectURL(_objectUrl!);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
    _objectUrl = web.URL.createObjectURL(blob);
    _video.src = _objectUrl!;
    _video.load();
  }

  /// Carrega o vídeo direto de uma URL remota (ex.: servido pela API local
  /// que rodou a transcrição/análise), sem precisar manter os bytes em memória.
  void loadFromUrl(String url) {
    if (_objectUrl != null) {
      web.URL.revokeObjectURL(_objectUrl!);
      _objectUrl = null;
    }
    _video.src = url;
    _video.load();
  }

  void play() => _video.play();
  void pause() => _video.pause();
  set currentTime(double t) => _video.currentTime = t;

  void setRotation(int degrees) {
    _video.style.transform = degrees == 0 ? '' : 'rotate(${degrees}deg)';
  }

  void dispose() {
    if (_objectUrl != null) web.URL.revokeObjectURL(_objectUrl!);
  }
}
