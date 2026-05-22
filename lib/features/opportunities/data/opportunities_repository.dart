import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'opportunity_model.dart';

final opportunitiesProvider = FutureProvider<List<Opportunity>>((ref) async {
  final data = await supabase
      .from('opportunities')
      .select()
      .order('created_at', ascending: false);
  return (data as List).map((e) => Opportunity.fromJson(e)).toList();
});

final opportunitiesRepoProvider =
    Provider<OpportunitiesRepository>((ref) => OpportunitiesRepository());

class OpportunitiesRepository {
  Future<Opportunity> upsert(Opportunity o) async {
    final payload =
        o.id.isEmpty ? o.toJson() : {...o.toJson(), 'id': o.id};
    final data = await supabase
        .from('opportunities')
        .upsert(payload)
        .select()
        .single();
    return Opportunity.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('opportunities').delete().eq('id', id);
  }
}
