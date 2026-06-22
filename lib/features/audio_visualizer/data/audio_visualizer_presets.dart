import '../../../core/supabase/supabase_client.dart';
import 'audio_visualizer_config.dart';

const _table = 'audio_visualizer_presets';

/// Persiste presets de configuracao do Audio Visualizer no Supabase,
/// escopados por organizacao (imagens nao sao salvas, apenas
/// valores numericos/cores/enums).
class AudioVisualizerPresetStore {
  Future<List<String>> listNames(String orgId) async {
    final rows = await supabase
        .from(_table)
        .select('name')
        .eq('organization_id', orgId)
        .order('name');
    return (rows as List).map((r) => r['name'] as String).toList();
  }

  Future<void> save(
      String orgId, String name, AudioVisualizerConfig config) async {
    await supabase.from(_table).upsert(
      {
        'organization_id': orgId,
        'name': name,
        'config': config.toPresetJson(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'organization_id,name',
    );
  }

  Future<AudioVisualizerConfig?> load(
      String orgId, String name, AudioVisualizerConfig base) async {
    final row = await supabase
        .from(_table)
        .select('config')
        .eq('organization_id', orgId)
        .eq('name', name)
        .maybeSingle();
    if (row == null) return null;
    return base.applyPresetJson(row['config'] as Map<String, dynamic>);
  }

  Future<void> delete(String orgId, String name) async {
    await supabase
        .from(_table)
        .delete()
        .eq('organization_id', orgId)
        .eq('name', name);
  }
}
