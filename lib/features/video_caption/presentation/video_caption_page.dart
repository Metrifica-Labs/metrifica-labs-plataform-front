import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../audio_visualizer/data/web_download.dart';
import '../../audio_visualizer/presentation/audio_visualizer_page.dart' show showColorPickerDialog;
import '../data/video_caption_models.dart';
import '../data/video_preview_engine.dart';

const _kApiBaseUrlPrefKey = 'video_caption_api_base_url';
const _kDefaultApiBaseUrl = 'http://localhost:3002';

// ── Paleta (espelha as custom properties do meal-video/public/index.html) ──
const _bg = Color(0xFF0A0A0C);
const _bg2 = Color(0xFF101013);
const _bg3 = Color(0xFF16161A);
const _bg4 = Color(0xFF1E1E24);
const _line = Color(0xFF1E1E26);
const _line2 = Color(0xFF2C2C38);
const _tx = Color(0xFFE6E6EE);
const _tx2 = Color(0xFF8888A0);
const _tx3 = Color(0xFF44445A);
const _acc = Color(0xFF00E5A0);
const _acc2 = Color(0x1F00E5A0);
const _acc3 = Color(0x0F00E5A0);
const _red = Color(0xFFFF3C58);
const _red2 = Color(0x38FF3C58);
const _keep = Color(0x12FFFFFF);

TextStyle _mono({double size = 11, Color color = _tx3, FontWeight? weight}) =>
    GoogleFonts.getFont('Space Mono',
        fontSize: size, color: color, fontWeight: weight);

TextStyle _sans({double size = 13, Color color = _tx, FontWeight? weight}) =>
    GoogleFonts.getFont('Syne', fontSize: size, color: color, fontWeight: weight);

enum _Screen { upload, processing, editor }

class _CutDrag {
  _CutDrag(this.cutIndex, this.isStart);
  final int cutIndex;
  final bool isStart;
}

class VideoCaptionPage extends StatefulWidget {
  const VideoCaptionPage({super.key});

  @override
  State<VideoCaptionPage> createState() => _VideoCaptionPageState();
}

class _VideoCaptionPageState extends State<VideoCaptionPage> {
  _Screen _screen = _Screen.upload;
  VideoPreviewEngine? _engine;
  VideoEdit? _edit;

  String _procStage = 'Iniciando...';
  double _procPct = 0;

  double _currentTime = 0;
  double _duration = 0;
  bool _playing = false;
  double? _segmentPreviewEnd;

  double _pps = 40;
  int _tab = 0;
  final _timelineScroll = ScrollController();
  bool _resizingCut = false;

  final List<String> _outros = [];
  String? _selectedOutro;

  String _apiBaseUrl = _kDefaultApiBaseUrl;
  CaptionStyle _captionStyle = const CaptionStyle();
  CaptionGap? _regeneratingGap;
  Size _videoBoxSize = Size.zero;
  bool _exporting = false;
  String? _exportingSegmentKey;

  @override
  void initState() {
    super.initState();
    _loadApiBaseUrl();
  }

  @override
  void dispose() {
    _engine?.dispose();
    _timelineScroll.dispose();
    super.dispose();
  }

  Future<void> _loadApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kApiBaseUrlPrefKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() => _apiBaseUrl = saved);
    }
  }

  Future<void> _editApiBaseUrl() async {
    final controller = TextEditingController(text: _apiBaseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg2,
        title: Text('URL do servidor de legenda/cortes', style: _sans(weight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: _mono(size: 13, color: _tx),
          decoration: InputDecoration(
            hintText: _kDefaultApiBaseUrl,
            hintStyle: _mono(size: 13),
            helperText: 'Endpoint local (ex.: http://localhost:3002) usado para\n'
                'gerar transcrição, cortes e legendas via IA.',
            helperMaxLines: 3,
            helperStyle: _mono(size: 10),
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _line2)),
          ).copyWith(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _line2)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiBaseUrlPrefKey, result);
    if (!mounted) return;
    setState(() => _apiBaseUrl = result);
  }

  // ── Upload / mock pipeline ──────────────────────────────────────────────

  Future<void> _pickAndProcess() async {
    final picked = await pickFileBytes('video/*');
    if (picked == null) return;
    final (name, bytes) = picked;
    await _processVideo(name, bytes);
  }

  /// Envia o vídeo para a API local (transcrição + análise de cortes) e
  /// espera a resposta pronta antes de abrir o editor — nenhuma prévia
  /// mockada é usada aqui.
  Future<void> _processVideo(String name, Uint8List bytes) async {
    setState(() {
      _screen = _Screen.processing;
      _procStage = 'Enviando vídeo...';
      _procPct = 5;
    });

    try {
      final id = await _uploadVideo(name, bytes);
      final edit = await _pollUntilReady(id);

      final engine = VideoPreviewEngine();
      engine.onTimeUpdate = (t) {
        if (!mounted) return;
        setState(() {
          _currentTime = t;
          if (_segmentPreviewEnd != null && t >= _segmentPreviewEnd!) {
            engine.pause();
            _segmentPreviewEnd = null;
          }
        });
      };
      engine.onPlayStateChanged = (p) {
        if (!mounted) return;
        setState(() => _playing = p);
      };
      engine.onLoadedMetadata = (d) {
        if (!mounted || d <= 0) return;
        setState(() => _duration = d);
      };
      engine.loadFromUrl('$_apiBaseUrl/videos/${edit.videoFileName}');

      if (!mounted) return;
      setState(() {
        _engine = engine;
        _edit = edit;
        _duration = edit.durationSeconds;
        _currentTime = 0;
        _screen = _Screen.editor;
        _tab = 0;
      });
      _loadOutros();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _procStage = 'Erro ao gerar legenda/cortes';
        _procPct = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Falha ao processar vídeo em $_apiBaseUrl: $e'),
        duration: const Duration(seconds: 6),
      ));
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _screen = _Screen.upload);
    }
  }

  Future<String> _uploadVideo(String name, Uint8List bytes) async {
    final uri = Uri.parse('$_apiBaseUrl/api/process');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('video', bytes, filename: name));
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 400) {
      throw Exception('HTTP ${streamed.statusCode}: $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final id = json['id'] as String?;
    if (id == null) throw Exception('Resposta sem "id": $body');
    return id;
  }

  static const _stageLabels = {
    'uploading': 'Recebendo vídeo...',
    'transcribing': 'Transcrevendo com Whisper...',
    'analyzing': 'Analisando cortes com IA...',
    'ready': 'Pronto!',
  };

  Future<VideoEdit> _pollUntilReady(String id) async {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 1200));
      final res = await http.get(Uri.parse('$_apiBaseUrl/api/status/$id'));
      if (res.statusCode >= 400) {
        throw Exception('HTTP ${res.statusCode} ao consultar status');
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final stage = json['stage'] as String? ?? 'uploading';
      final progress = (json['progress'] as num?)?.toDouble() ?? 0;

      if (stage == 'error') {
        throw Exception(json['error'] as String? ?? 'erro desconhecido no pipeline');
      }

      if (!mounted) throw Exception('cancelado');
      setState(() {
        _procStage = _stageLabels[stage] ?? (json['message'] as String? ?? stage);
        _procPct = progress;
      });

      if (stage == 'ready') {
        final editJson = json['edit'] as Map<String, dynamic>?;
        if (editJson == null) throw Exception('status "ready" sem campo "edit"');
        return VideoEdit.fromJson(editJson);
      }
    }
  }

  /// Reprocessa só o trecho [gap] (fala sem legenda) pedindo ao servidor
  /// para gerar legendas cobrindo aquelas palavras, e funde o resultado de
  /// volta na lista de legendas do edit atual.
  Future<void> _regenerateGap(CaptionGap gap) async {
    final edit = _edit;
    if (edit == null || _regeneratingGap != null) return;
    setState(() => _regeneratingGap = gap);
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/regenerate-captions/${edit.id}');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'start': gap.start, 'end': gap.end}),
      );
      if (res.statusCode >= 400) throw Exception('HTTP ${res.statusCode}: ${res.body}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final newCaptions = (json['captions'] as List? ?? [])
          .map((c) => Caption.fromJson(c as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        final startFrame = (gap.start * edit.fps).round();
        final endFrame = (gap.end * edit.fps).round();
        edit.captions.removeWhere(
            (c) => c.startFrame >= startFrame && c.endFrame <= endFrame);
        edit.captions.addAll(newCaptions);
        edit.captions.sort((a, b) => a.startFrame.compareTo(b.startFrame));
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newCaptions.isEmpty
            ? 'Nenhuma legenda gerada para ${fmtTime(gap.start)}–${fmtTime(gap.end)}.'
            : '${newCaptions.length} legenda(s) gerada(s) para ${fmtTime(gap.start)}–${fmtTime(gap.end)}.'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao gerar legenda para o trecho: $e'),
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _regeneratingGap = null);
    }
  }

  Future<void> _loadOutros() async {
    try {
      final res = await http.get(Uri.parse('$_apiBaseUrl/api/outros'));
      if (res.statusCode >= 400) return;
      final list = jsonDecode(res.body) as List;
      final names = list.map((o) => (o as Map<String, dynamic>)['filename'] as String).toList();
      if (!mounted) return;
      setState(() => _outros
        ..clear()
        ..addAll(names));
    } catch (_) {
      // Lista de encerramentos é um extra opcional — falha silenciosa.
    }
  }

  Future<void> _uploadOutro() async {
    final picked = await pickFileBytes('video/*');
    if (picked == null) return;
    final (name, bytes) = picked;
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/upload-outro');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes('outro', bytes, filename: name));
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 400) throw Exception('HTTP ${streamed.statusCode}: $body');
      final filename = (jsonDecode(body) as Map<String, dynamic>)['filename'] as String;
      if (!mounted) return;
      setState(() => _outros.add(filename));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar encerramento: $e')));
    }
  }

  Future<void> _deleteOutro(String filename) async {
    setState(() {
      _outros.remove(filename);
      if (_selectedOutro == filename) _selectedOutro = null;
    });
    try {
      await http.delete(Uri.parse('$_apiBaseUrl/api/outros/${Uri.encodeComponent(filename)}'));
    } catch (_) {
      // Mantém removido localmente mesmo se a chamada falhar.
    }
  }

  void _goUpload() {
    _engine?.dispose();
    setState(() {
      _engine = null;
      _edit = null;
      _screen = _Screen.upload;
    });
  }

  /// Converte um [Color] do Flutter para um inteiro 0xAARRGGBB, formato que
  /// o servidor espera para traduzir pra cor ASS (&HAABBGGRR).
  int _colorToArgb32(Color c) {
    final a = (c.a * 255).round().clamp(0, 255);
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Área realmente ocupada pelo vídeo dentro da caixa do player, já
  /// descontando as faixas pretas do `object-fit: contain` quando a
  /// proporção do vídeo não bate com a da caixa.
  Size _renderedVideoSize(Size box, int videoW, int videoH) {
    if (videoW <= 0 || videoH <= 0 || box.width <= 0 || box.height <= 0) return box;
    final boxRatio = box.width / box.height;
    final videoRatio = videoW / videoH;
    if (videoRatio > boxRatio) {
      return Size(box.width, box.width / videoRatio);
    }
    return Size(box.height * videoRatio, box.height);
  }

  /// Estilo de legenda do preview convertido em proporções relativas ao
  /// vídeo, para que o servidor reproduza o mesmo visual independente da
  /// resolução real do arquivo exportado.
  Map<String, dynamic> _styleExportPayload() {
    final rendered = _renderedVideoSize(
      _videoBoxSize,
      _engine?.videoWidth ?? 0,
      _engine?.videoHeight ?? 0,
    );
    return {
      'fontFamily': _captionStyle.fontFamily,
      'fontSizeRatio': rendered.width > 0 ? _captionStyle.fontSize / rendered.width : 0.046,
      'textColor': _colorToArgb32(_captionStyle.textColor),
      'backgroundColor': _colorToArgb32(_captionStyle.backgroundColor),
      'bottomOffsetRatio': rendered.height > 0 ? _captionStyle.bottomOffset / rendered.height : 0.08,
      'maxWidthPercent': _captionStyle.maxWidthPercent,
    };
  }

  /// Envia os cortes/legendas/rotação editados na UI para o servidor antes
  /// de exportar, já que ele exporta a partir do JSON salvo no disco.
  Future<void> _syncEditToServer(VideoEdit edit) async {
    final res = await http.put(
      Uri.parse('$_apiBaseUrl/api/edits/${edit.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cuts': edit.cuts.map((c) => {'start': c.start, 'end': c.end, 'reason': c.reason}).toList(),
        'captions': edit.captions
            .map((c) => {
                  'startFrame': c.startFrame,
                  'endFrame': c.endFrame,
                  'text': c.text,
                  if (c.words != null)
                    'words': c.words!
                        .map((w) => {'word': w.word, 'startFrame': w.startFrame, 'endFrame': w.endFrame})
                        .toList(),
                })
            .toList(),
        'rotation': edit.rotation,
      }),
    );
    if (res.statusCode >= 400) {
      throw Exception('falha ao sincronizar edição (HTTP ${res.statusCode})');
    }
  }

  String _extractError(http.Response res) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'HTTP ${res.statusCode}';
    } catch (_) {
      return 'HTTP ${res.statusCode}';
    }
  }

  Future<void> _exportFull() async {
    final edit = _edit;
    if (edit == null || _exporting) return;
    setState(() => _exporting = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Exportando vídeo completo (cortes + legendas)... isso pode levar alguns minutos.'),
      duration: Duration(seconds: 6),
    ));
    try {
      await _syncEditToServer(edit);
      final res = await http.post(
        Uri.parse('$_apiBaseUrl/api/export-full/${edit.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rotation': edit.rotation,
          if (_selectedOutro != null) 'outroFilename': _selectedOutro,
          'style': _styleExportPayload(),
        }),
      );
      if (res.statusCode >= 400) throw Exception(_extractError(res));

      downloadBytes(res.bodyBytes, 'video-completo-${edit.videoFileName}.mp4', 'video/mp4');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exportação concluída! Download iniciado '
            '(${(res.bodyBytes.length / 1048576).toStringAsFixed(1)} MB).'),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao exportar vídeo: $e'),
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportSegment(double start, double end) async {
    final edit = _edit;
    if (edit == null || _exportingSegmentKey != null) return;
    final key = '$start-$end';
    setState(() => _exportingSegmentKey = key);
    try {
      await _syncEditToServer(edit);
      final res = await http.post(
        Uri.parse('$_apiBaseUrl/api/export-segment/${edit.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'start': start,
          'end': end,
          'rotation': edit.rotation,
          if (_selectedOutro != null) 'outroFilename': _selectedOutro,
          'style': _styleExportPayload(),
        }),
      );
      if (res.statusCode >= 400) throw Exception(_extractError(res));

      downloadBytes(res.bodyBytes, 'trecho-${fmtTime(start).replaceAll(':', '-')}.mp4', 'video/mp4');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Download do trecho iniciado.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erro ao exportar trecho: $e'),
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _exportingSegmentKey = null);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: switch (_screen) {
        _Screen.upload => _buildUploadScreen(),
        _Screen.processing => _buildProcessingScreen(),
        _Screen.editor => _buildEditorScreen(),
      },
    );
  }

  Widget _buildUploadScreen() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LEGENDA DE VÍDEO',
                  style: _mono(size: 11, color: _acc, weight: FontWeight.w700)
                      .copyWith(letterSpacing: 4)),
              const SizedBox(height: 28),
              InkWell(
                onTap: _pickAndProcess,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 460,
                  height: 260,
                  decoration: BoxDecoration(
                    color: _bg2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line2, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _line2, width: 1.5),
                        ),
                        child: const Center(
                            child: Icon(Icons.play_arrow, color: _tx2, size: 20)),
                      ),
                      const SizedBox(height: 12),
                      Text('Solte seu vídeo aqui',
                          style: _sans(size: 17, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('MP4 · MOV · AVI  —  clique para selecionar',
                          style: _mono(size: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _editApiBaseUrl,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.settings_outlined, size: 13, color: _tx3),
                      const SizedBox(width: 6),
                      Text('Servidor de IA: $_apiBaseUrl', style: _mono(size: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            tooltip: 'Configurar servidor de legenda/cortes',
            onPressed: _editApiBaseUrl,
            icon: const Icon(Icons.settings_outlined, color: _tx2),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('LEGENDA DE VÍDEO',
              style: _mono(size: 11, color: _acc, weight: FontWeight.w700)
                  .copyWith(letterSpacing: 4)),
          const SizedBox(height: 26),
          Text(_procStage, style: _sans(size: 22, weight: FontWeight.w700)),
          const SizedBox(height: 26),
          SizedBox(
            width: 320,
            height: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _procPct / 100,
                backgroundColor: _line,
                color: _acc,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(_procPct >= 100 ? 'Concluído!' : 'Aguarde...', style: _mono()),
        ],
      ),
    );
  }

  Widget _buildEditorScreen() {
    final edit = _edit!;
    return Column(
      children: [
        _topbar(edit),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _videoCol(edit)),
              Container(width: 340, color: _bg2, child: _panelCol(edit)),
            ],
          ),
        ),
        _timelineSection(edit),
      ],
    );
  }

  // ── Topbar ───────────────────────────────────────────────────────────────

  Widget _topbar(VideoEdit edit) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: _bg2,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Text('LEGENDA DE VÍDEO',
              style: _mono(size: 11, color: _acc, weight: FontWeight.w700)
                  .copyWith(letterSpacing: 2.4)),
          const SizedBox(width: 12),
          Container(width: 1, height: 13, color: _line2),
          const SizedBox(width: 12),
          Expanded(
            child: Text(edit.videoFileName,
                overflow: TextOverflow.ellipsis, style: _mono(size: 12, color: _tx2)),
          ),
          IconButton(
            tooltip: 'Servidor de IA: $_apiBaseUrl',
            onPressed: _editApiBaseUrl,
            icon: const Icon(Icons.settings_outlined, color: _tx2, size: 18),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: _goUpload,
            style: OutlinedButton.styleFrom(
              foregroundColor: _tx2,
              side: const BorderSide(color: _line2),
            ),
            child: const Text('+ Novo Vídeo'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _exporting ? null : _exportFull,
            style: FilledButton.styleFrom(
              backgroundColor: _acc,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _line2,
            ),
            child: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Exportar Tudo'),
          ),
        ],
      ),
    );
  }

  // ── Coluna de vídeo ──────────────────────────────────────────────────────

  Widget _videoCol(VideoEdit edit) {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              _videoBoxSize = constraints.biggest;
              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(child: HtmlElementView(viewType: _engine!.viewType)),
                  Positioned(
                    bottom: _captionStyle.bottomOffset,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(child: _captionOverlay(edit)),
                  ),
                ],
              );
            }),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: _bg2,
              border: Border(top: BorderSide(color: _line)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _playing ? _engine!.pause() : _engine!.play(),
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow, color: _tx2),
                ),
                Text(fmtTime(_currentTime), style: _mono()),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: _acc,
                      inactiveTrackColor: _line2,
                      thumbColor: _acc,
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: _currentTime.clamp(0, _duration > 0 ? _duration : 1),
                      max: _duration > 0 ? _duration : 1,
                      onChanged: (v) {
                        _segmentPreviewEnd = null;
                        _engine!.currentTime = v;
                        setState(() => _currentTime = v);
                      },
                    ),
                  ),
                ),
                Text(fmtTime(_duration), style: _mono()),
                IconButton(
                  tooltip: 'Girar vídeo 90°',
                  onPressed: () {
                    setState(() {
                      edit.rotation = (edit.rotation + 90) % 360;
                      _engine!.setRotation(edit.rotation);
                    });
                  },
                  icon: const Icon(Icons.rotate_right, color: _tx2, size: 18),
                ),
                if (edit.rotation != 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _acc2, borderRadius: BorderRadius.circular(4)),
                    child: Text('${edit.rotation}°', style: _mono(size: 10, color: _acc)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Caption? _activeCaption(VideoEdit edit) {
    final frame = (_currentTime * edit.fps).round();
    for (final c in edit.captions) {
      if (frame >= c.startFrame && frame <= c.endFrame) return c;
    }
    return null;
  }

  Widget _captionOverlay(VideoEdit edit) {
    final active = _activeCaption(edit);
    if (active == null) return const SizedBox.shrink();
    final frame = (_currentTime * edit.fps).round();

    Widget content;
    if (active.words != null && active.words!.isNotEmpty) {
      content = Text.rich(
        TextSpan(
          children: active.words!.map((w) {
            Color color;
            List<Shadow>? shadow;
            if (frame >= w.startFrame && frame <= w.endFrame) {
              color = _captionStyle.textColor;
              shadow = const [Shadow(color: _acc, blurRadius: 14)];
            } else if (frame > w.endFrame) {
              color = _captionStyle.textColor.withValues(alpha: 0.7);
            } else {
              color = _captionStyle.textColor.withValues(alpha: 0.45);
            }
            return TextSpan(
              text: '${w.word} ',
              style: TextStyle(
                color: color,
                fontSize: _captionStyle.fontSize,
                fontWeight: FontWeight.w700,
                shadows: shadow,
                fontFamily: _resolveFontFamily(_captionStyle.fontFamily),
              ),
            );
          }).toList(),
        ),
        textAlign: TextAlign.center,
      );
    } else {
      content = Text(active.text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _captionStyle.textColor,
            fontSize: _captionStyle.fontSize,
            fontWeight: FontWeight.w700,
            fontFamily: _resolveFontFamily(_captionStyle.fontFamily),
          ));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth * (_captionStyle.maxWidthPercent / 100);
      return Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _captionStyle.backgroundColor,
            borderRadius: BorderRadius.circular(7),
          ),
          child: content,
        ),
      );
    });
  }

  // ── Painel lateral ───────────────────────────────────────────────────────

  Widget _panelCol(VideoEdit edit) {
    const labels = ['CORTES', 'LEGENDAS', 'SEGMENTOS', 'ANÁLISE', 'ESTILO'];
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
          child: Row(
            children: List.generate(labels.length, (i) {
              final on = i == _tab;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: on ? _acc : Colors.transparent, width: 2)),
                    ),
                    child: Center(
                      child: Text(labels[i],
                          style: _mono(size: 10, color: on ? _acc : _tx3, weight: FontWeight.w700)
                              .copyWith(letterSpacing: 1)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            0 => _cutsTab(edit),
            1 => _captionsTab(edit),
            2 => _segmentsTab(edit),
            3 => _analysisTab(edit),
            _ => _styleTab(),
          },
        ),
      ],
    );
  }

  Widget _emptyState(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(child: Text(text, style: _mono(size: 11))),
      );

  /// Cria um corte manual de ~1s a partir da posição atual do playhead —
  /// disponível mesmo quando a IA não sugeriu nenhum corte para o vídeo.
  void _addManualCut(VideoEdit edit) {
    final start = _currentTime.clamp(0, edit.durationSeconds - 0.2).toDouble();
    final end = (start + 1.0).clamp(start + 0.2, edit.durationSeconds).toDouble();
    setState(() {
      edit.cuts.add(Cut(start: start, end: end, reason: 'Corte manual'));
      edit.cuts.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  Widget _cutsTab(VideoEdit edit) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: edit.cuts.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                if (edit.cuts.isEmpty)
                  Expanded(
                    child: Text('Nenhum corte sugerido pela IA.',
                        style: _mono(size: 11, color: _tx3)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _addManualCut(edit),
                  icon: const Icon(Icons.content_cut, size: 14, color: _acc),
                  label: Text('Cortar na posição atual', style: _sans(size: 11, color: _acc)),
                ),
              ],
            ),
          );
        }
        final cut = edit.cuts[i - 1];
        return Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _bg3,
            borderRadius: BorderRadius.circular(6),
            border: const Border(
              top: BorderSide(color: _line),
              right: BorderSide(color: _line),
              bottom: BorderSide(color: _line),
              left: BorderSide(color: _red, width: 2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${fmtTime(cut.start)} → ${fmtTime(cut.end)}  ·  ${fmtDuration(cut.end - cut.start)}',
                      style: _mono(size: 10, color: _red),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => edit.cuts.removeAt(i - 1)),
                    child: const Icon(Icons.close, size: 14, color: _tx3),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(cut.reason, style: _sans(size: 12, color: _tx2)),
              const SizedBox(height: 7),
              Row(
                children: [
                  _timeField(fmtTime(cut.start), (v) {
                    final t = parseTimeInput(v);
                    if (t == null) return;
                    setState(() => cut.start = t.clamp(0, cut.end - 0.2));
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text('→', style: _mono(size: 11)),
                  ),
                  _timeField(fmtTime(cut.end), (v) {
                    final t = parseTimeInput(v);
                    if (t == null) return;
                    setState(() => cut.end = t.clamp(cut.start + 0.2, edit.durationSeconds));
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timeField(String initial, ValueChanged<String> onSubmit) {
    return SizedBox(
      width: 54,
      child: TextFormField(
        initialValue: initial,
        textAlign: TextAlign.center,
        style: _mono(size: 11, color: _tx),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
          filled: true,
          fillColor: _bg4,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _line2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _line2),
          ),
        ),
        onFieldSubmitted: onSubmit,
      ),
    );
  }

  Widget _gapsCard(List<CaptionGap> gaps) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg3,
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: _red, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${gaps.length} trecho${gaps.length != 1 ? 's' : ''} com fala sem legenda',
            style: _sans(size: 12, weight: FontWeight.w700, color: _red),
          ),
          const SizedBox(height: 8),
          ...gaps.map((gap) {
            final busy = _regeneratingGap?.start == gap.start && _regeneratingGap?.end == gap.end;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${fmtTime(gap.start)} → ${fmtTime(gap.end)}', style: _mono(size: 11)),
                  ),
                  TextButton(
                    onPressed: _regeneratingGap == null ? () => _regenerateGap(gap) : null,
                    style: TextButton.styleFrom(
                      backgroundColor: _acc,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: _line2,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('Gerar legenda', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Largura útil (em px) disponível pro texto da legenda, considerando a
  /// largura máxima configurada e o tamanho real do vídeo exibido — mesma
  /// conta usada pelo overlay, pra detectar quando uma legenda vai quebrar
  /// em mais de 2 linhas.
  double _captionMaxWidthPx() {
    if (_videoBoxSize == Size.zero) return 600;
    final rendered = _renderedVideoSize(
      _videoBoxSize,
      _engine?.videoWidth ?? 0,
      _engine?.videoHeight ?? 0,
    );
    final boxWidth = rendered.width * (_captionStyle.maxWidthPercent / 100);
    return (boxWidth - 28).clamp(40, double.infinity); // 28 = padding horizontal (14*2) da caixa
  }

  int _countWrappedLines(String text, double maxWidthPx) {
    if (text.isEmpty) return 1;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: _captionStyle.fontSize,
          fontWeight: FontWeight.w700,
          fontFamily: _resolveFontFamily(_captionStyle.fontFamily),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidthPx);
    return painter.computeLineMetrics().length;
  }

  /// Empacota greedily o máximo de índices consecutivos (0..[length)) em
  /// cada grupo, respeitando [fits] — usado tanto pra dividir uma legenda
  /// longa quanto pra reagrupar todas as palavras do zero, maximizando
  /// quanto cabe por legenda em vez de bisseccionar (que em listas curtas
  /// degenera em cortar item por item).
  List<List<int>> _greedyPackIndices(int length, bool Function(int start, int end) fits) {
    final groups = <List<int>>[];
    var idx = 0;
    while (idx < length) {
      var end = idx;
      while (end + 1 < length && fits(idx, end + 1)) {
        end++;
      }
      groups.add(List.generate(end - idx + 1, (k) => idx + k));
      idx = end + 1;
    }
    return groups;
  }

  /// Divide [cap] em partes que cabem em no máximo 2 linhas na largura
  /// [maxWidthPx].
  ///
  /// Quando há timing palavra-a-palavra ([cap.words]), os grupos são
  /// formados a partir desse array — e não de `cap.text.split(' ')` — pra
  /// garantir que o texto exibido e o timing usado sempre vêm da mesma
  /// fonte. `cap.text` (saída "limpa" da IA) pode não corresponder 1:1 às
  /// palavras brutas do Whisper; usar índices de um pra cortar o outro é o
  /// que causava o dessincronismo.
  List<Caption> _splitCaptionToFit(Caption cap, double maxWidthPx) {
    if (_countWrappedLines(cap.text, maxWidthPx) <= 2) return [cap];

    final hasWordTiming = cap.words != null && cap.words!.isNotEmpty;
    final tokens = hasWordTiming
        ? cap.words!.map((w) => w.word).toList()
        : cap.text.trim().split(RegExp(r'\s+'));
    if (tokens.length <= 1) return [cap];

    final groups = _greedyPackIndices(tokens.length, (s, e) {
      return _countWrappedLines(tokens.sublist(s, e + 1).join(' '), maxWidthPx) <= 2;
    });

    return groups.map((group) {
      final startIdx = group.first;
      final endIdx = group.last;
      final text = tokens.sublist(startIdx, endIdx + 1).join(' ');

      if (hasWordTiming) {
        final partWords = cap.words!.sublist(startIdx, endIdx + 1);
        return Caption(
          startFrame: partWords.first.startFrame,
          endFrame: partWords.last.endFrame,
          text: text,
          words: partWords,
        );
      }
      final totalFrames = cap.endFrame - cap.startFrame;
      final startFrame = cap.startFrame + (totalFrames * startIdx / tokens.length).round();
      final endFrame = cap.startFrame + (totalFrames * (endIdx + 1) / tokens.length).round();
      return Caption(startFrame: startFrame, endFrame: endFrame, text: text);
    }).toList();
  }

  /// Reagrupa uma sequência contínua de palavras (já sem cortes de pausa
  /// natural no meio) em legendas que usam o máximo de espaço disponível,
  /// até 2 linhas cada.
  List<Caption> _packWords(List<CaptionWord> words, double maxWidthPx) {
    if (words.isEmpty) return [];
    final groups = _greedyPackIndices(words.length, (s, e) {
      final candidate = words.sublist(s, e + 1).map((w) => w.word).join(' ');
      return _countWrappedLines(candidate, maxWidthPx) <= 2;
    });
    return groups.map((g) {
      final slice = words.sublist(g.first, g.last + 1);
      return Caption(
        startFrame: slice.first.startFrame,
        endFrame: slice.last.endFrame,
        text: slice.map((w) => w.word).join(' '),
        words: slice,
      );
    }).toList();
  }

  /// Reconstrói toda a lista de legendas a partir do array bruto de
  /// palavras de cada uma, ignorando os agrupamentos curtos que a IA
  /// sugeriu originalmente (máx. 6 palavras) e empacotando o máximo que
  /// cabe em 2 linhas — só preservando uma quebra onde já havia uma pausa
  /// real na fala, pra não juntar frases sem relação. Legendas sem timing
  /// palavra-a-palavra (texto editado manualmente) são mantidas como estão.
  void _reflowAllCaptions(VideoEdit edit) {
    final maxWidthPx = _captionMaxWidthPx();
    const maxGapSeconds = 0.7;

    final result = <Caption>[];
    final pending = <CaptionWord>[];

    void flushPending() {
      if (pending.isEmpty) return;
      result.addAll(_packWords(List.of(pending), maxWidthPx));
      pending.clear();
    }

    for (final cap in edit.captions) {
      if (cap.words == null || cap.words!.isEmpty) {
        flushPending();
        result.add(cap);
        continue;
      }
      for (final w in cap.words!) {
        if (pending.isNotEmpty) {
          final gap = (w.startFrame - pending.last.endFrame) / edit.fps;
          if (gap > maxGapSeconds) flushPending();
        }
        pending.add(w);
      }
    }
    flushPending();

    setState(() {
      edit.captions
        ..clear()
        ..addAll(result);
    });
  }

  void _autoSplitCaption(VideoEdit edit, Caption cap) {
    final parts = _splitCaptionToFit(cap, _captionMaxWidthPx());
    if (parts.length <= 1) return;
    setState(() {
      final idx = edit.captions.indexOf(cap);
      if (idx == -1) return;
      edit.captions.removeAt(idx);
      edit.captions.insertAll(idx, parts);
    });
  }

  Widget _longCaptionsCard(VideoEdit edit, List<Caption> longCaptions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg3,
        borderRadius: BorderRadius.circular(6),
        border: const Border(left: BorderSide(color: _red, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${longCaptions.length} legenda${longCaptions.length != 1 ? 's' : ''} com mais de 2 linhas',
              style: _sans(size: 12, weight: FontWeight.w700, color: _red),
            ),
          ),
          TextButton(
            onPressed: () => _reflowAllCaptions(edit),
            style: TextButton.styleFrom(
              backgroundColor: _acc,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            child: const Text('Reotimizar', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _captionsTab(VideoEdit edit) {
    final gaps = findCaptionGaps(edit);
    final maxWidthPx = _captionMaxWidthPx();
    final longCaptions =
        edit.captions.where((c) => _countWrappedLines(c.text, maxWidthPx) > 2).toList();

    if (edit.captions.isEmpty && gaps.isEmpty) return _emptyState('Nenhuma legenda');

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (gaps.isNotEmpty) _gapsCard(gaps),
        if (longCaptions.isNotEmpty) _longCaptionsCard(edit, longCaptions),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextButton.icon(
              onPressed: () => _reflowAllCaptions(edit),
              icon: const Icon(Icons.auto_fix_high, size: 14, color: _acc),
              label: Text('Reotimizar legendas (usar mais o espaço)',
                  style: _sans(size: 11, color: _acc)),
            ),
          ),
        ),
        ...edit.captions.map((cap) {
          final lit = _activeCaption(edit) == cap;
          final lines = _countWrappedLines(cap.text, maxWidthPx);
          final tooLong = lines > 2;
          return InkWell(
            onTap: () {
              _segmentPreviewEnd = null;
              _engine!.currentTime = cap.startFrame / edit.fps;
              setState(() => _currentTime = cap.startFrame / edit.fps);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: lit ? _acc3 : _bg3,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tooLong ? _red : (lit ? _acc : _line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${fmtTime(cap.startFrame / edit.fps)} → ${fmtTime(cap.endFrame / edit.fps)}',
                            style: _mono(size: 10)),
                      ),
                      if (tooLong) Text('$lines linhas', style: _mono(size: 9, color: _red)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: cap.text,
                    maxLines: 2,
                    style: _sans(size: 13, weight: FontWeight.w600),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onChanged: (v) => setState(() {
                      cap.text = v;
                      // Timing palavra-a-palavra não corresponde mais ao texto
                      // editado — cai para exibir o texto inteiro no overlay.
                      cap.words = null;
                    }),
                  ),
                  if (tooLong) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _autoSplitCaption(edit, cap),
                        style: TextButton.styleFrom(
                          backgroundColor: _acc,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: const Text('Dividir em 2 linhas', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _segmentsTab(VideoEdit edit) {
    final keeps = computeKeepSegments(edit);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _outroSection(),
        const SizedBox(height: 10),
        Text('SEGMENTOS', style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 8),
        if (keeps.isEmpty) _emptyState('Sem segmentos'),
        ...keeps.map((k) {
          final isPreviewing = _segmentPreviewEnd == k.end && _playing;
          return Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPreviewing ? _acc3 : _bg3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isPreviewing ? _acc : _line),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (isPreviewing) {
                      _engine!.pause();
                      setState(() => _segmentPreviewEnd = null);
                      return;
                    }
                    _engine!.currentTime = k.start;
                    _engine!.play();
                    setState(() => _segmentPreviewEnd = k.end);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isPreviewing ? _acc : _acc2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(isPreviewing ? Icons.pause : Icons.play_arrow,
                        size: 16, color: isPreviewing ? Colors.black : _acc),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${fmtTime(k.start)} → ${fmtTime(k.end)}  ·  ${fmtDuration(k.end - k.start)}',
                      style: _mono(size: 11, color: _tx2)),
                ),
                TextButton(
                  onPressed: _exportingSegmentKey == null
                      ? () => _exportSegment(k.start, k.end)
                      : null,
                  style: TextButton.styleFrom(
                    backgroundColor: _acc,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _line2,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  child: _exportingSegmentKey == '${k.start}-${k.end}'
                      ? const SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Exportar', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _outroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ENCERRAMENTO', style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
            const Spacer(),
            InkWell(
              onTap: _uploadOutro,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: _bg4, borderRadius: BorderRadius.circular(4), border: Border.all(color: _line2)),
                child: Text('+ Adicionar', style: _sans(size: 11, color: _tx2, weight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_outros.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhum encerramento adicionado', style: _mono(size: 11)),
            ),
          )
        else
          ..._outros.map((name) {
            final sel = _selectedOutro == name;
            return InkWell(
              onTap: () => setState(() => _selectedOutro = sel ? null : name),
              child: Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? _acc3 : _bg4,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: sel ? _acc : _line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel ? _acc : Colors.transparent,
                        border: Border.all(color: sel ? _acc : _tx3, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, overflow: TextOverflow.ellipsis, style: _sans(size: 11, color: sel ? _tx : _tx2))),
                    InkWell(
                      onTap: () => _deleteOutro(name),
                      child: const Icon(Icons.close, size: 13, color: _tx3),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _analysisTab(VideoEdit edit) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(edit.analysisNotes, style: _sans(size: 13, color: _tx2)),
    );
  }

  String? _resolveFontFamily(String name) {
    try {
      return GoogleFonts.getFont(name).fontFamily;
    } catch (_) {
      return GoogleFonts.getFont('Syne').fontFamily;
    }
  }

  Widget _styleTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('FONTE', style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _captionStyle.fontFamily,
          style: _sans(size: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Nome da fonte (Google Fonts), ex.: Syne, Inter, Roboto',
            hintStyle: _mono(size: 10),
            filled: true,
            fillColor: _bg4,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _line2)),
          ),
          onFieldSubmitted: (v) {
            final name = v.trim();
            if (name.isEmpty) return;
            try {
              GoogleFonts.getFont(name);
            } catch (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Fonte "$name" não encontrada no Google Fonts.')),
              );
              return;
            }
            setState(() => _captionStyle = _captionStyle.copyWith(fontFamily: name));
          },
        ),
        const SizedBox(height: 20),
        _styleRow('TAMANHO DA FONTE', _CaptionStepperField(
          value: _captionStyle.fontSize,
          min: 10,
          max: 64,
          step: 1,
          isInt: true,
          onChanged: (v) => setState(() => _captionStyle = _captionStyle.copyWith(fontSize: v)),
        )),
        const SizedBox(height: 16),
        _styleRow('POSIÇÃO (DISTÂNCIA DO RODAPÉ)', _CaptionStepperField(
          value: _captionStyle.bottomOffset,
          min: 0,
          max: 300,
          step: 4,
          isInt: true,
          onChanged: (v) => setState(() => _captionStyle = _captionStyle.copyWith(bottomOffset: v)),
        )),
        const SizedBox(height: 16),
        _styleRow('LARGURA MÁXIMA (% DO VÍDEO)', _CaptionStepperField(
          value: _captionStyle.maxWidthPercent,
          min: 20,
          max: 100,
          step: 5,
          isInt: true,
          onChanged: (v) => setState(() => _captionStyle = _captionStyle.copyWith(maxWidthPercent: v)),
        )),
        const SizedBox(height: 20),
        Text('COR DA FONTE', style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showColorPickerDialog(context, _captionStyle.textColor);
            if (picked != null) setState(() => _captionStyle = _captionStyle.copyWith(textColor: picked));
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: _bg4,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _line2),
            ),
            alignment: Alignment.center,
            child: Text('Toque para escolher a cor',
                style: _mono(size: 11, color: _captionStyle.textColor)),
          ),
        ),
        const SizedBox(height: 20),
        Text('FUNDO DA LEGENDA', style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showColorPickerDialog(context, _captionStyle.backgroundColor);
            if (picked != null) setState(() => _captionStyle = _captionStyle.copyWith(backgroundColor: picked));
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: _captionStyle.backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _line2),
            ),
            alignment: Alignment.center,
            child: Text('Toque para escolher a cor', style: _mono(size: 11, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _styleRow(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  // ── Timeline ─────────────────────────────────────────────────────────────

  void _scrubTo(double localDx, double totalW, double dur) {
    final t = (localDx / totalW * dur).clamp(0, dur);
    _segmentPreviewEnd = null;
    _engine!.currentTime = t.toDouble();
    setState(() => _currentTime = t.toDouble());
  }

  Widget _timelineSection(VideoEdit edit) {
    final totalCut = edit.cuts.fold<double>(0, (a, c) => a + (c.end - c.start));
    return Container(
      height: 230,
      decoration: const BoxDecoration(color: _bg2, border: Border(top: BorderSide(color: _line))),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
            child: Row(
              children: [
                Text('TIMELINE', style: _mono(size: 9, color: _tx3).copyWith(letterSpacing: 1.2)),
                const SizedBox(width: 10),
                _zoomBtn(Icons.remove, () => setState(() => _pps = (_pps - 15).clamp(4, 250))),
                SizedBox(
                  width: 36,
                  child: Center(child: Text(_zoomLabel(), style: _mono(size: 10))),
                ),
                _zoomBtn(Icons.add, () => setState(() => _pps = (_pps + 15).clamp(4, 250))),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    final w = (context.size?.width ?? 800) - 56 - 20;
                    setState(() => _pps = (w / edit.durationSeconds).clamp(4, 250));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: _line)),
                    child: Text('Ajustar', style: _mono(size: 10)),
                  ),
                ),
                const Spacer(),
                Text(fmtTime(_currentTime), style: _mono(size: 11, color: _acc)),
                const SizedBox(width: 10),
                Text(
                  '${edit.cuts.length} corte${edit.cuts.length != 1 ? 's' : ''} · −${fmtTime(totalCut)} · ${edit.captions.length} legendas',
                  style: _mono(size: 10),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: _line))),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 44, child: Padding(padding: const EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: Text('VÍDEO', style: _mono(size: 9))))),
                        SizedBox(height: 28, child: Padding(padding: const EdgeInsets.only(left: 8, top: 4), child: Align(alignment: Alignment.centerLeft, child: Text('CAPS', style: _mono(size: 9))))),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final totalW = (edit.durationSeconds * _pps).clamp(constraints.maxWidth, double.infinity);
                    return SingleChildScrollView(
                      controller: _timelineScroll,
                      scrollDirection: Axis.horizontal,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerMove: (d) {
                          if (_resizingCut) return;
                          _scrubTo(d.localPosition.dx, totalW, edit.durationSeconds);
                        },
                        onPointerUp: (d) {
                          if (_resizingCut) return;
                          _scrubTo(d.localPosition.dx, totalW, edit.durationSeconds);
                        },
                        child: SizedBox(
                          width: totalW,
                          child: Stack(
                            children: [
                              _ruler(totalW, edit.durationSeconds),
                              Positioned(top: 22, left: 0, right: 0, height: 44, child: _videoTrack(edit, totalW)),
                              Positioned(top: 70, left: 0, right: 0, height: 28, child: _capsTrack(edit, totalW)),
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: (_currentTime / edit.durationSeconds * totalW).clamp(0, totalW) - 1,
                                width: 2,
                                child: Container(color: _acc),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _zoomLabel() {
    if (_pps <= 15) return '0.5×';
    if (_pps <= 40) return '1×';
    if (_pps <= 90) return '2×';
    return '4×';
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: _bg4, borderRadius: BorderRadius.circular(4), border: Border.all(color: _line2)),
        child: Icon(icon, size: 13, color: _tx2),
      ),
    );
  }

  Widget _ruler(double totalW, double dur) {
    final rawInterval = 80 / _pps;
    const niceIntervals = [0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300];
    final interval = niceIntervals.firstWhere((n) => n >= rawInterval, orElse: () => 300);
    final majorEvery = interval < 5 ? 5 : (interval < 30 ? 4 : 2);

    final marks = <Widget>[];
    var count = 0;
    for (var t = 0.0; t <= dur + 0.001; t += interval) {
      final left = t / dur * totalW;
      final isMajor = count % majorEvery == 0;
      marks.add(Positioned(
        left: left,
        top: 0,
        bottom: 0,
        child: Container(
          width: 1,
          alignment: Alignment.bottomCenter,
          color: isMajor ? _line2 : Colors.transparent,
          child: isMajor
              ? Transform.translate(
                  offset: const Offset(0, -2),
                  child: Text(fmtTime(t), style: _mono(size: 9)))
              : null,
        ),
      ));
      count++;
    }
    return Container(
      height: 22,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line))),
      child: Stack(children: marks),
    );
  }

  Widget _videoTrack(VideoEdit edit, double totalW) {
    final dur = edit.durationSeconds;
    final sorted = List<Cut>.from(edit.cuts)..sort((a, b) => a.start.compareTo(b.start));
    final segments = <Widget>[];
    var cursor = 0.0;

    for (final cut in sorted) {
      final origIdx = edit.cuts.indexOf(cut);
      if (cut.start > cursor + 0.02) {
        final l = cursor / dur * totalW;
        final w = (cut.start - cursor) / dur * totalW;
        segments.add(Positioned(
          left: l,
          width: w,
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(color: _keep, border: Border.all(color: _line2), borderRadius: BorderRadius.circular(3)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text('${fmtTime(cursor)} → ${fmtTime(cut.start)}',
                overflow: TextOverflow.clip, maxLines: 1, style: _mono(size: 9, color: _tx2)),
          ),
        ));
      }

      final l = cut.start / dur * totalW;
      final w = ((cut.end - cut.start) / dur * totalW).clamp(4.0, double.infinity);
      segments.add(Positioned(
        left: l,
        width: w,
        top: 0,
        bottom: 0,
        child: Container(
          decoration: BoxDecoration(color: _red2, border: Border.all(color: const Color(0x59FF3C58)), borderRadius: BorderRadius.circular(3)),
          child: Stack(
            children: [
              Center(child: Text('✕ ${fmtDuration(cut.end - cut.start)}', style: _mono(size: 9, color: _red))),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 8,
                child: _dragHandle(_CutDrag(origIdx, true)),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 8,
                child: _dragHandle(_CutDrag(origIdx, false)),
              ),
            ],
          ),
        ),
      ));
      cursor = cut.end;
    }

    if (cursor < dur - 0.02) {
      final l = cursor / dur * totalW;
      final w = (dur - cursor) / dur * totalW;
      segments.add(Positioned(
        left: l,
        width: w,
        top: 0,
        bottom: 0,
        child: Container(
          decoration: BoxDecoration(color: _keep, border: Border.all(color: _line2), borderRadius: BorderRadius.circular(3)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Text('${fmtTime(cursor)} → ${fmtTime(dur)}', maxLines: 1, style: _mono(size: 9, color: _tx2)),
        ),
      ));
    }

    return Padding(padding: const EdgeInsets.only(top: 4), child: Stack(children: segments));
  }

  Widget _dragHandle(_CutDrag drag) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _resizingCut = true,
      onHorizontalDragEnd: (_) => _resizingCut = false,
      onHorizontalDragCancel: () => _resizingCut = false,
      onHorizontalDragUpdate: (details) {
        final cut = _edit!.cuts[drag.cutIndex];
        final dt = details.delta.dx / _pps;
        const minLen = 0.2;
        setState(() {
          if (drag.isStart) {
            cut.start = (cut.start + dt).clamp(0, cut.end - minLen);
          } else {
            cut.end = (cut.end + dt).clamp(cut.start + minLen, _edit!.durationSeconds);
          }
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _capsTrack(VideoEdit edit, double totalW) {
    final dur = edit.durationSeconds;
    final active = _activeCaption(edit);
    return Stack(
      children: edit.captions.map((c) {
        final ss = c.startFrame / edit.fps;
        final es = c.endFrame / edit.fps;
        final l = ss / dur * totalW;
        final w = ((es - ss) / dur * totalW).clamp(3.0, double.infinity);
        final lit = active == c;
        return Positioned(
          left: l,
          width: w,
          top: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: lit ? _acc3 : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(c.text, maxLines: 1, overflow: TextOverflow.clip, style: _mono(size: 8)),
          ),
        );
      }).toList(),
    );
  }
}

/// Campo numérico com texto editável + botões +/-, usado nos controles de
/// estilo de legenda (tamanho da fonte, posição).
class _CaptionStepperField extends StatefulWidget {
  const _CaptionStepperField({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.isInt = false,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final bool isInt;
  final ValueChanged<double> onChanged;

  @override
  State<_CaptionStepperField> createState() => _CaptionStepperFieldState();
}

class _CaptionStepperFieldState extends State<_CaptionStepperField> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  String _format(double v) => widget.isInt ? v.round().toString() : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _submit(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant _CaptionStepperField oldWidget) {
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
      width: 140,
      height: 32,
      child: Row(
        children: [
          _stepButton(Icons.remove, () => _step(-widget.step)),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: _mono(size: 12, color: _tx),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                filled: true,
                fillColor: _bg4,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: _line2),
                ),
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
        child: Icon(icon, size: 16, color: _tx2),
      ),
    );
  }
}
