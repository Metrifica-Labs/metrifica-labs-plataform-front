import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/organization_model.dart';
import '../../../core/providers/organization_provider.dart';
import '../data/audio_visualizer_config.dart';
import '../data/audio_visualizer_engine.dart';
import '../data/audio_visualizer_presets.dart';
import '../data/captions.dart';
import '../data/transcription_service.dart';
import '../data/web_download.dart';

class AudioVisualizerPage extends ConsumerStatefulWidget {
  const AudioVisualizerPage({super.key});

  @override
  ConsumerState<AudioVisualizerPage> createState() =>
      _AudioVisualizerPageState();
}

class _AudioVisualizerPageState extends ConsumerState<AudioVisualizerPage> {
  final AudioVisualizerEngine _engine = AudioVisualizerEngine();
  final AudioVisualizerPresetStore _presetStore = AudioVisualizerPresetStore();
  AudioVisualizerConfig _config = const AudioVisualizerConfig();

  List<String> _presetNames = [];
  String? _selectedPreset;

  String? _audioName;
  Uint8List? _audioBytes;
  String _audioMime = 'audio/mpeg';
  String? _captionsName;
  int _captionWordCount = 0;

  VizPlaybackState _state = VizPlaybackState.idle;
  double _current = 0;
  double _total = 0;
  bool _recording = false;
  bool _converting = false;
  String? _statusMessage;
  bool _loadingAudio = false;
  bool _transcribing = false;
  late ProviderSubscription<OrganizationModel?> _orgSub;

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
    _engine.onConversionChanged = (c) {
      setState(() => _converting = c);
    };
    _engine.onConversionProgress = (p) {
      setState(() => _statusMessage =
          'Convertendo para MP4... ${(p * 100).clamp(0, 100).toStringAsFixed(0)}%');
    };
    _engine.updateConfig(_config);
    _orgSub = ref.listenManual<OrganizationModel?>(
      activeOrgProvider,
      (_, next) {
        if (next != null) _loadPresetNames();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _orgSub.close();
    _engine.dispose();
    super.dispose();
  }

  void _apply(AudioVisualizerConfig next) {
    setState(() => _config = next);
    _engine.updateConfig(next);
  }

  // ---- Presets ----------------------------------------------------------

  Future<void> _loadPresetNames() async {
    final orgId = ref.read(activeOrgProvider)?.id;
    if (orgId == null) return;
    final names = await _presetStore.listNames(orgId);
    if (!mounted) return;
    setState(() {
      _presetNames = names;
      if (_selectedPreset != null && !names.contains(_selectedPreset)) {
        _selectedPreset = null;
      }
    });
  }

  Future<void> _savePresetDialog() async {
    final controller = TextEditingController(text: _selectedPreset ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do preset'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final orgId = ref.read(activeOrgProvider)?.id;
    if (orgId == null) return;
    await _presetStore.save(orgId, name, _config);
    if (!mounted) return;
    setState(() {
      _selectedPreset = name;
      _statusMessage = 'Preset "$name" salvo.';
    });
    await _loadPresetNames();
  }

  Future<void> _loadSelectedPreset() async {
    final name = _selectedPreset;
    if (name == null) return;
    final orgId = ref.read(activeOrgProvider)?.id;
    if (orgId == null) return;
    final loaded = await _presetStore.load(orgId, name, _config);
    if (loaded == null) return;
    _apply(loaded);
    setState(() => _statusMessage = 'Preset "$name" carregado.');
  }

  Future<void> _deleteSelectedPreset() async {
    final name = _selectedPreset;
    if (name == null) return;
    final orgId = ref.read(activeOrgProvider)?.id;
    if (orgId == null) return;
    await _presetStore.delete(orgId, name);
    if (!mounted) return;
    setState(() {
      _selectedPreset = null;
      _statusMessage = 'Preset "$name" excluido.';
    });
    await _loadPresetNames();
  }

  // ---- Pickers ---------------------------------------------------------------

  Future<void> _pickAudio() async {
    final picked = await pickFileBytes('audio/*');
    if (picked == null) return;
    final (name, bytes) = picked;
    final mime = _guessAudioMime(name);
    setState(() {
      _loadingAudio = true;
      _audioName = name;
      _audioBytes = bytes;
      _audioMime = mime;
      _statusMessage = null;
    });
    await _engine.loadAudio(bytes, mime: mime);
    if (mounted) setState(() => _loadingAudio = false);
  }

  Future<void> _transcribeAudio() async {
    final bytes = _audioBytes;
    if (bytes == null) return;
    setState(() {
      _transcribing = true;
      _statusMessage = 'Transcrevendo áudio...';
    });
    try {
      final captions = await transcribeAudio(bytes, _audioMime);
      _engine.setCaptions(captions);
      if (!mounted) return;
      setState(() {
        _captionsName = 'Transcrição automática';
        _captionWordCount = captions.words.length;
        _statusMessage = captions.isEmpty
            ? 'Transcrição concluída, mas nenhuma fala foi detectada.'
            : 'Transcrição concluída (${captions.words.length} palavras).';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Erro ao transcrever: $e');
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
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
    final ext = mime.contains('mp4') ? 'mp4' : 'webm';
    downloadBytes(bytes, '$base.$ext', mime);
    setState(() => _statusMessage = ext == 'mp4'
        ? 'Pronto! Download do .mp4 iniciado (${(bytes.length / 1048576).toStringAsFixed(1)} MB).'
        : 'Não foi possível gerar .mp4 (sem conexão?); baixamos o .webm '
            '(${(bytes.length / 1048576).toStringAsFixed(1)} MB).');
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
    final canExport =
        _engine.hasAudio && !_recording && !_loadingAudio && !_converting;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canExport ? _startExport : null,
            icon: _converting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.movie_creation_outlined),
            label: Text(_recording
                ? 'Gravando ${_fmt(_current)} / ${_fmt(_total)}'
                : _converting
                    ? 'Convertendo para MP4...'
                    : 'Gerar e baixar (.mp4)'),
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
        _section('Presets'),
        _presetPanel(),

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
              : 'Opcional — gere com scripts/transcribe.py ou transcreva automaticamente',
          onTap: _pickCaptions,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _audioBytes != null && !_transcribing
                  ? _transcribeAudio
                  : null,
              icon: _transcribing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                  _transcribing ? 'Transcrevendo...' : 'Transcrever automaticamente'),
            ),
          ),
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
        _numberField(
          label: 'FPS',
          value: _config.fps.toDouble(),
          min: 15,
          max: 60,
          step: 1,
          isInt: true,
          onChanged: (v) => _apply(_config.copyWith(fps: v.round())),
        ),

        _section('Anel (espectro)'),
        _colorRow('Cor inicial', _config.ringColorStart,
            (c) => _apply(_config.copyWith(ringColorStart: c))),
        _colorRow('Cor final', _config.ringColorEnd,
            (c) => _apply(_config.copyWith(ringColorEnd: c))),
        _numberField(
          label: 'Nº de barras',
          value: _config.barCount.toDouble(),
          min: 24,
          max: 180,
          step: 1,
          isInt: true,
          onChanged: (v) => _apply(_config.copyWith(barCount: v.round())),
        ),
        _numberField(
          label: 'Raio do anel',
          value: _config.ringRadius,
          min: 0.15,
          max: 0.45,
          step: 0.01,
          onChanged: (v) => _apply(_config.copyWith(ringRadius: v)),
        ),
        _numberField(
          label: 'Largura da barra',
          value: _config.barWidth,
          min: 2,
          max: 16,
          step: 0.5,
          onChanged: (v) => _apply(_config.copyWith(barWidth: v)),
        ),
        _numberField(
          label: 'Altura máx. da barra',
          value: _config.barMaxLength,
          min: 40,
          max: 260,
          step: 5,
          onChanged: (v) => _apply(_config.copyWith(barMaxLength: v)),
        ),
        _numberField(
          label: 'Sensibilidade',
          value: _config.sensitivity,
          min: 0.4,
          max: 2.5,
          step: 0.05,
          onChanged: (v) => _apply(_config.copyWith(sensitivity: v)),
        ),
        _numberField(
          label: 'Velocidade de rotação',
          value: _config.rotationSpeed,
          min: 0,
          max: 30,
          step: 1,
          onChanged: (v) => _apply(_config.copyWith(rotationSpeed: v)),
        ),
        _switch('Brilho (glow)', _config.glow,
            (v) => _apply(_config.copyWith(glow: v))),

        _section('Imagem central'),
        _numberField(
          label: 'Tamanho',
          value: _config.centerImageScale,
          min: 0.4,
          max: 1.0,
          step: 0.05,
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
        _numberField(
          label: 'Tamanho da fonte',
          value: _config.captionFontSize,
          min: 20,
          max: 96,
          step: 1,
          onChanged: (v) => _apply(_config.copyWith(captionFontSize: v)),
        ),
        _colorRow('Cor do texto', _config.captionColor,
            (c) => _apply(_config.copyWith(captionColor: c))),
        _colorRow('Cor do destaque', _config.captionHighlightColor,
            (c) => _apply(_config.copyWith(captionHighlightColor: c))),
        _numberField(
          label: 'Posição (de baixo)',
          value: _config.captionBottomOffset,
          min: 0.05,
          max: 0.5,
          step: 0.01,
          onChanged: (v) => _apply(_config.copyWith(captionBottomOffset: v)),
        ),
        _numberField(
          label: 'Palavras por linha (karaoke)',
          value: _config.captionMaxWords.toDouble(),
          min: 1,
          max: 10,
          step: 1,
          isInt: true,
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

  Widget _numberField({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    bool isInt = false,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500))),
          _NumberStepperField(
            value: value,
            min: min,
            max: max,
            step: step,
            isInt: isInt,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _presetPanel() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedPreset,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(),
              hintText: 'Selecione um preset',
            ),
            items: _presetNames
                .map((n) => DropdownMenuItem(
                      value: n,
                      child:
                          Text(n, style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedPreset = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectedPreset == null ? null : _loadSelectedPreset,
                  icon: const Icon(Icons.file_open_outlined, size: 16),
                  label: const Text('Carregar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _selectedPreset == null ? null : _deleteSelectedPreset,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Excluir'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _savePresetDialog,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Salvar preset atual'),
            ),
          ),
        ],
      ),
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

/// Campo numerico com botoes +/- para ajuste fino dos parametros.
class _NumberStepperField extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final bool isInt;
  final ValueChanged<double> onChanged;

  const _NumberStepperField({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.isInt = false,
  });

  @override
  State<_NumberStepperField> createState() => _NumberStepperFieldState();
}

class _NumberStepperFieldState extends State<_NumberStepperField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  String _format(double v) =>
      widget.isInt ? v.round().toString() : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _submit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant _NumberStepperField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _step(double delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    _controller.text = _format(next);
    widget.onChanged(next);
  }

  void _submit(String text) {
    final parsed = double.tryParse(text.trim().replaceAll(',', '.'));
    if (parsed == null) {
      _controller.text = _format(widget.value);
      return;
    }
    final clamped = parsed.clamp(widget.min, widget.max);
    _controller.text = _format(clamped);
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      height: 32,
      child: Row(
        children: [
          _stepButton(Icons.remove, () => _step(-widget.step)),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                border: OutlineInputBorder(),
              ),
              onSubmitted: _submit,
            ),
          ),
          _stepButton(Icons.add, () => _step(widget.step)),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 16),
      ),
    );
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
