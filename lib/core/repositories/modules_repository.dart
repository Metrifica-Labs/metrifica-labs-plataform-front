import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/module_model.dart';
import '../supabase/supabase_client.dart';

final modulesProvider = FutureProvider<List<ModuleModel>>((ref) async {
  final data = await supabase.from('modules').select().order('created_at');
  return (data as List).map((e) => ModuleModel.fromJson(e)).toList();
});

final moduleBySlugProvider =
    FutureProvider.family<ModuleModel?, String>((ref, slug) async {
  final data = await supabase
      .from('modules')
      .select()
      .eq('slug', slug)
      .maybeSingle();
  if (data == null) return null;
  return ModuleModel.fromJson(data);
});

class ModulesRepository {
  Future<ModuleModel> upsert(ModuleModel module) async {
    final payload = {...module.toJson(), 'id': module.id};
    final data = await supabase
        .from('modules')
        .upsert(payload)
        .select()
        .single();
    return ModuleModel.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('modules').delete().eq('id', id);
  }
}

final modulesRepositoryProvider =
    Provider<ModulesRepository>((ref) => ModulesRepository());
