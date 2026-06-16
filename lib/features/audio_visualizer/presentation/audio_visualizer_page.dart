import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/audio_visualizer_config.dart';
import '../data/audio_visualizer_engine.dart';
import '../data/captions.dart';
import '../data/web_download.dart';

class AudioVisualizerPage extends StatefulWidget {
  const AudioVisualizerPage({super.key});

  @override
  State<AudioVisualizerPage> createState() => _AudioVisualizerPageState();
}

class _AudioVisualizerPageState extends State<AudioVisualizerPage> {
  final AudioVisualizerEngine _engine = AudioVisualizerEngine();
  AudioVisualizerConfig _config = const AudioVisualizerConfig();

  String? _audioName;
  String? _captionsName;
  int _captionWordCount = 0;

  VizPlaybackState _state = VizPlaybackState.idle;
  double _current = 0;
  double _total = 0;
  bool _recording = false;
  String? _statusMessage;
  bool _loadingAudio = false;

  @override
  void initState() {
    super.initState();
    _engine.onStateChanged = (s) {
      setState(() => _state = s);
    };
    _engine.onProgress = (c, t) {
      setState(() {
        _current = c;
        _total = t;
      });
    };
    _engine.onRecordingChanged = (r) {
      setState(() => _recording = r);
    };
    _engine.onExportReady = _handleExportReady;
    _engine.updateConfig(_config);
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  void _apply(AudioVisualizerConfig next) {
    setState(() => _config = next);
    _engine.updateConfig(next);
  }

  // ---- Pickers ---------------------------------------------------------------

  Future<void> _pickAudio() async {
    final picked = await pickFileBytes('audio/*');
    if (picked == null) return;
    final (name, bytes) = picked;
    setState(() {
      _loadingAudio = true;
      _audioName = name;
      _statusMessage = null;
    });
    await _engine.loadAudio(bytes, mime: _guessAudioMime(name));
    if (mounted) setState(() => _loadingAudio = false);
  }

  Future<void> _pickCaptions() async {
    final picked = await pickFileBytes('.json,.srt,.vtt,application/json,text/plain');
    if (picked == null) return;
    final (name, bytes) = picked;
    final captions = Captions.parse(utf8.decode(bytes, allowMalformed: true));
    _engine.setCaptions(captions);
    setState(() {
      _captionsName = name;
      _captionWordCount = captions.words.length;
    });
  }

  Future<void> _pickCenterImage() async {
    final picked = await pickFileBytes('image/*');
    if (picked == null) return;
    final (_, bytes) = picked;
    await _engine.setCenterImage(bytes);
    _apply(_config.copyWith(centerImageBytes: bytes));
  }

  Future<void> _pickBackgroundImage() async {
    final picked = await pickFileBytes('image/*');
    if (picked == null) return;
    final (_, bytes) = picked;
    await _engine.setBackgroundImage(bytes);
    _apply(_config.copyWith(
      backgroundImageBytes: bytes,
      backgroundType: BackgroundType.image,
    ));
  }

  String _guessAudioMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.mp3')) return 'audio/mpeg';
    if (n.endsWith('.wav')) return 'audio/wav';
    if (n.endsWith('.m4a') || n.endsWith('.aac')) return 'audio/mp4';
    if (n.endsWith('.ogg')) return 'audio/ogg';
    if (n.endsWith('.webm')) return 'audio/webm';
    return 'audio/mpeg';
  }

  // ---- Playback / export -----------------------------------------------------

  Future<void> _togglePlay() async {
    if (_state == VizPlaybackState.playing) {
      _engine.pause();
    } else {
      await _engine.play();
    }
  }

  Future<void> _startExport() async {
    setState(() => _statusMessage = 'Gravando... o vídeo é gerado em tempo '
        'real, então leva o tempo do áudio. Não troque de aba.');
    await _engine.startExport();
  }

  void _handleExportReady(Uint8List bytes, String mime) {
    final base = (_audioName ?? 'audio-visualizer').replaceAll(
        RegExp(r'\.[^.]+$'), '');
    downloadBytes(bytes, '$base.webm', mime);
    setState(() => _statusMessage =
        'Pronto! Download iniciado (${(bytes.length / 1048576).toStringAsFixed(1)} MB).');
  }

  // ---- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1100;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 380, child: _buildConfigPanel()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildPreviewPanel()),
                ],
              )
            : ListView(
                children: [
                  _buildPreviewPanel(),
                  _buildConfigPanel(),
                ],
              ),
      ),
    );
  }

  Widget _buildPreviewPanel() {
    final theme = Theme.of(context);
    final ratio = _config.aspect.width / _config.aspect.height;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              Text('Audio Visualizer',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_recording)
                Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('REC', style: theme.textTheme.labelMedium),
                ]),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: HtmlElementView(viewType: _engine.viewType),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTransport(),
          const SizedBox(height: 12),
          _buildExportRow(),
          if (_statusMessage != null) ...[
            const SizedBox(height: 10),
            Text(_statusMessage!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _buildTransport() {
    final hasAudio = _engine.hasAudio;
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: hasAudio && !_recording ? _togglePlay : null,
          icon: Icon(_state == VizPlaybackState.playing
              ? Icons.pause
              : Icons.play_arrow),
        ),
        const SizedBox(width: 8),
        Text(_fmt(_current)),
        Expanded(
          child: Slider(
            value: _total > 0 ? _current.clamp(0, _total) : 0,
            max: _total > 0 ? _total : 1,
            onChanged: hasAudio && !_recording
                ? (v) {
                    _engine.seek(v);
                    setState(() => _current = v);
                  }
                : null,
          ),
        ),
        Text(_fmt(_total)),
      ],
    );
  }

  Widget _buildExportRow() {
    final canExport = _engine.hasAudio && !_recording && !_loadingAudio;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canExport ? _startExport : null,
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(_recording
                ? 'Gravando ${_fmt(_current)} / ${_fmt(_total)}'
                : 'Gerar e baixar (.webm)'),
          ),
        ),
        if (_recording) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _engine.cancelExport,
            child: const Text('Cancelar'),
          ),
        ],
      ],
    );
  }

  Widget _buildConfigPanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        _section('Arquivos'),
        _fileTile(
          icon: Icons.audiotrack,
          title: 'Áudio',
          subtitle: _loadingAudio
              ? 'Carregando...'
              : (_audioName ?? 'Selecione um arquivo (mp3, wav, m4a...)'),
          onTap: _pickAudio,
        ),
        _fileTile(
          icon: Icons.subtitles_outlined,
          title: 'Legenda (JSON do transcribe.py / SRT)',
          subtitle: _captionsName != null
              ? '$_captionsName — $_captionWordCount palavras'
              : 'Opcional — gere com scripts/transcribe.py',
          onTap: _pickCaptions,
        ),
        _fileTile(
          icon: Icons.image_outlined,
          title: 'Imagem central',
          subtitle: _config.centerImageBytes != null
              ? 'Imagem carregada'
              : 'Selecione a imagem do meio do anel',
          onTap: _pickCenterImage,
        ),

        _section('Formato'),
        _dropdown<VideoAspect>(
          label: 'Proporção',
          value: _config.aspect,
          items: VideoAspect.values,
          labelOf: (a) => a.label,
          onChanged: (v) => _apply(_config.copyWith(aspect: v)),
        ),
        _slider(
          label: 'FPS',
          value: _config.fps.toDouble(),
          min: 15,
          max: 60,
          divisions: 9,
          display: _config.fps.toString(),
          onChanged: (v) => _apply(_config.copyWith(fps: v.round())),
        ),

        _section('Anel (espectro)'),
        _colorRow('Cor inicial', _config.ringColorStart,
            (c) => _apply(_config.copyWith(ringColorStart: c))),
        _colorRow('Cor final', _config.ringColorEnd,
            (c) => _apply(_config.copyWith(ringColorEnd: c))),
        _slider(
          label: 'Nº de barras',
          value: _config.barCount.toDouble(),
          min: 24,
          max: 180,
          divisions: 52,
          display: _config.barCount.toString(),
          onChanged: (v) => _apply(_config.copyWith(barCount: v.round())),
        ),
        _slider(
          label: 'Raio do anel',
          value: _config.ringRadius,
          min: 0.15,
          max: 0.45,
          onChanged: (v) => _apply(_config.copyWith(ringRadius: v)),
        ),
        _slider(
          label: 'Largura da barra',
          value: _config.barWidth,
          min: 2,
          max: 16,
          onChanged: (v) => _apply(_config.copyWith(barWidth: v)),
        ),
        _slider(
          label: 'Altura máx. da barra',
          value: _config.barMaxLength,
          min: 40,
          max: 260,
          onChanged: (v) => _apply(_config.copyWith(barMaxLength: v)),
        ),
        _slider(
          label: 'Sensibilidade',
          value: _config.sensitivity,
          min: 0.4,
          max: 2.5,
          onChanged: (v) => _apply(_config.copyWith(sensitivity: v)),
        ),
        _slider(
          label: 'Velocidade de rotação',
          value: _config.rotationSpeed,
          min: 0,
          max: 30,
          onChanged: (v) => _apply(_config.copyWith(rotationSpeed: v)),
        ),
        _switch('Brilho (glow)', _config.glow,
            (v) => _apply(_config.copyWith(glow: v))),

        _section('Imagem central'),
        _slider(
          label: 'Tamanho',
          value: _config.centerImageScale,
          min: 0.4,
          max: 1.0,
          onChanged: (v) => _apply(_config.copyWith(centerImageScale: v)),
        ),
        _switch('Recorte circular', _config.centerImageCircular,
            (v) => _apply(_config.copyWith(centerImageCircular: v))),
        _switch('Pulsar com o áudio', _config.centerImagePulse,
            (v) => _apply(_config.copyWith(centerImagePulse: v))),

        _section('Fundo'),
        _dropdown<BackgroundType>(
          label: 'Tipo',
          value: _config.backgroundType,
          items: BackgroundType.values,
          labelOf: (t) => switch (t) {
            BackgroundType.solid => 'Cor sólida',
            BackgroundType.gradient => 'Gradiente',
            BackgroundType.image => 'Imagem',
          },
          onChanged: (v) => _apply(_config.copyWith(backgroundType: v)),
        ),
        _colorRow('Cor', _config.backgroundColor,
            (c) => _apply(_config.copyWith(backgroundColor: c))),
        if (_config.backgroundType == BackgroundType.gradient)
          _colorRow('Cor 2', _config.backgroundColor2,
              (c) => _apply(_config.copyWith(backgroundColor2: c))),
        if (_config.backgroundType == BackgroundType.image)
          _fileTile(
            icon: Icons.wallpaper_outlined,
            title: 'Imagem de fundo',
            subtitle: _config.backgroundImageBytes != null
                ? 'Imagem carregada'
                : 'Selecione a imagem de fundo',
            onTap: _pickBackgroundImage,
          ),

        _section('Legenda'),
        _switch('Mostrar legenda', _config.captionEnabled,
            (v) => _apply(_config.copyWith(captionEnabled: v))),
        _dropdown<CaptionMode>(
          label: 'Modo',
          value: _config.captionMode,
          items: CaptionMode.values,
          labelOf: (m) => m.label,
          onChanged: (v) => _apply(_config.copyWith(captionMode: v)),
        ),
        _slider(
          label: 'Tamanho da fonte',
          value: _config.captionFontSize,
          min: 20,
          max: 96,
          onChanged: (v) => _apply(_config.copyWith(captionFontSize: v)),
        ),
        _colorRow('Cor do texto', _config.captionColor,
            (c) => _apply(_config.copyWith(captionColor: c))),
        _colorRow('Cor do destaque', _config.captionHighlightColor,
            (c) => _apply(_config.copyWith(captionHighlightColor: c))),
        _slider(
          label: 'Posição (de baixo)',
          value: _config.captionBottomOffset,
          min: 0.05,
          max: 0.5,
          onChanged: (v) => _apply(_config.copyWith(captionBottomOffset: v)),
        ),
        _slider(
          label: 'Palavras por linha (karaoke)',
          value: _config.captionMaxWords.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          display: _config.captionMaxWords.toString(),
          onChanged: (v) => _apply(_config.copyWith(captionMaxWords: v.round())),
        ),
        _switch('Negrito', _config.captionBold,
            (v) => _apply(_config.copyWith(captionBold: v))),
        _switch('Sombra', _config.captionShadow,
            (v) => _apply(_config.copyWith(captionShadow: v))),
      ],
    );
  }

  // ---- Helpers de widget -----------------------------------------------------

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _fileTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.upload_file,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    String? display,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500))),
            Text(display ?? value.toStringAsFixed(2),
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(labelOf(e),
                          style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _colorRow(String label, Color color, ValueChanged<Color> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
          InkWell(
            onTap: () async {
              final picked =
                  await showColorPickerDialog(context, color);
              if (picked != null) onChanged(picked);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 36,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double seconds) {
    if (!seconds.isFinite || seconds < 0) seconds = 0;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).floor().toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// Dialog simples de cor com sliders RGBA + presets.
Future<Color?> showColorPickerDialog(
    BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorPickerDialog(initial: initial),
  );
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _r, _g, _b, _a;

  static const _presets = [
    Color(0xFFEC4899),
    Color(0xFF6366F1),
    Color(0xFF06B6D4),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  @override
  void initState() {
    super.initState();
    _r = (widget.initial.r * 255);
    _g = (widget.initial.g * 255);
    _b = (widget.initial.b * 255);
    _a = widget.initial.a;
  }

  Color get _color => Color.fromRGBO(_r.round(), _g.round(), _b.round(), _a);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cor'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(height: 12),
            _channel('R', _r, Colors.red, (v) => setState(() => _r = v)),
            _channel('G', _g, Colors.green, (v) => setState(() => _g = v)),
            _channel('B', _b, Colors.blue, (v) => setState(() => _b = v)),
            _channel('A', _a * 255, Colors.grey,
                (v) => setState(() => _a = v / 255)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets
                  .map((c) => InkWell(
                        onTap: () => setState(() {
                          _r = c.r * 255;
                          _g = c.g * 255;
                          _b = c.b * 255;
                          _a = 1;
                        }),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _color),
            child: const Text('OK')),
      ],
    );
  }

  Widget _channel(
      String label, double value, Color tint, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 16, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, 255),
            max: 255,
            activeColor: tint,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
            width: 32,
            child: Text(value.round().toString(),
                textAlign: TextAlign.right)),
      ],
    );
  }
}
