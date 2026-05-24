import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_definition_model.dart';
import '../supabase/supabase_client.dart';

final agentDefinitionsProvider =
    FutureProvider<List<AgentDefinitionModel>>((ref) async {
  final data =
      await supabase.from('agent_definitions').select().order('created_at');
  return (data as List).map((e) => AgentDefinitionModel.fromJson(e)).toList();
});

final agentsBySlugListProvider =
    FutureProvider.family<List<AgentDefinitionModel>, List<String>>(
        (ref, slugs) async {
  if (slugs.isEmpty) return [];
  final data = await supabase
      .from('agent_definitions')
      .select()
      .inFilter('slug', slugs);
  return (data as List).map((e) => AgentDefinitionModel.fromJson(e)).toList();
});
