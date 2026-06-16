import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'audio_visualizer_config.dart';

const _prefsKey = 'audio_visualizer_presets_v1';

/// Persiste presets de configuracao do Audio Visualizer localmente
/// (imagens nao sao salvas, apenas valores numericos/cores/enums).
class AudioVisualizerPresetStore {
  Future<Map<String, dynamic>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(all));
  }

  Future<List<String>> listNames() async {
    final all = await _readAll();
    return all.keys.toList()..sort();
  }

  Future<void> save(String name, AudioVisualizerConfig config) async {
    final all = await _readAll();
    all[name] = config.toPresetJson();
    await _writeAll(all);
  }

  Future<AudioVisualizerConfig?> load(
      String name, AudioVisualizerConfig base) async {
    final all = await _readAll();
    final json = all[name];
    if (json == null) return null;
    return base.applyPresetJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String name) async {
    final all = await _readAll();
    all.remove(name);
    await _writeAll(all);
  }
}
