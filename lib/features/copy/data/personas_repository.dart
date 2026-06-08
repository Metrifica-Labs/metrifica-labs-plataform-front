import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/organization_provider.dart';
import '../../../core/supabase/supabase_client.dart';
import 'persona_model.dart';

final personasProvider = FutureProvider<List<PersonaModel>>((ref) async {
  final org = ref.watch(activeOrgProvider);
  if (org == null) return [];
  final data = await supabase
      .from('personas')
      .select()
      .eq('org_id', org.id)
      .order('created_at', ascending: false);
  return (data as List).map((e) => PersonaModel.fromJson(e)).toList();
});

final selectedPersonaProvider = StateProvider<PersonaModel?>((ref) => null);

class PersonasRepository {
  Future<PersonaModel> create({
    required String orgId,
    required String name,
    required String content,
  }) async {
    final row = await supabase.from('personas').insert({
      'org_id': orgId,
      'name': name,
      'content': content,
    }).select().single();
    return PersonaModel.fromJson(row);
  }

  Future<PersonaModel> update({
    required String id,
    String? name,
    String? content,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      if (name != null) 'name': name,
      if (content != null) 'content': content,
    };
    final row = await supabase
        .from('personas')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return PersonaModel.fromJson(row);
  }

  Future<void> delete(String id) async {
    await supabase.from('personas').delete().eq('id', id);
  }
}

final personasRepoProvider =
    Provider<PersonasRepository>((ref) => PersonasRepository());
