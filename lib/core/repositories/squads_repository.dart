import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/squad_definition_model.dart';
import '../supabase/supabase_client.dart';

final squadsProvider = FutureProvider<List<SquadDefinitionModel>>((ref) async {
  final data =
      await supabase.from('squad_definitions').select().order('created_at');
  return (data as List).map((e) => SquadDefinitionModel.fromJson(e)).toList();
});

final squadBySlugProvider =
    FutureProvider.family<SquadDefinitionModel?, String>((ref, slug) async {
  final data = await supabase
      .from('squad_definitions')
      .select()
      .eq('slug', slug)
      .maybeSingle();
  if (data == null) return null;
  return SquadDefinitionModel.fromJson(data);
});
