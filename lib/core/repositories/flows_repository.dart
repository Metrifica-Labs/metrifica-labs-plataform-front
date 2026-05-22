import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flow_model.dart';
import '../supabase/supabase_client.dart';

final flowsProvider = FutureProvider<List<FlowModel>>((ref) async {
  final data = await supabase.from('flows').select().order('created_at');
  return (data as List).map((e) => FlowModel.fromJson(e)).toList();
});

final flowBySlugProvider =
    FutureProvider.family<FlowModel?, String>((ref, slug) async {
  final data = await supabase
      .from('flows')
      .select()
      .eq('slug', slug)
      .maybeSingle();
  if (data == null) return null;
  return FlowModel.fromJson(data);
});
