import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'narrative_model.dart';

final narrativesProvider = FutureProvider<List<Narrative>>((ref) async {
  final data = await supabase.from('narratives').select().order('type');
  return (data as List).map((e) => Narrative.fromJson(e)).toList();
});

final narrativesRepoProvider =
    Provider<NarrativesRepository>((ref) => NarrativesRepository());

class NarrativesRepository {
  Future<Narrative> upsert(Narrative n) async {
    final payload =
        n.id.isEmpty ? n.toJson() : {...n.toJson(), 'id': n.id};
    final data =
        await supabase.from('narratives').upsert(payload).select().single();
    return Narrative.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('narratives').delete().eq('id', id);
  }
}
