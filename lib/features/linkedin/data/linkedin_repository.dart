import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'linkedin_model.dart';

final linkedinMetricsProvider =
    FutureProvider<List<LinkedinMetrics>>((ref) async {
  final data = await supabase
      .from('linkedin_metrics')
      .select()
      .order('month', ascending: false);
  return (data as List).map((e) => LinkedinMetrics.fromJson(e)).toList();
});

final linkedinRepoProvider =
    Provider<LinkedinRepository>((ref) => LinkedinRepository());

class LinkedinRepository {
  Future<LinkedinMetrics> upsert(LinkedinMetrics m) async {
    final payload = m.id.isEmpty
        ? m.toJson()
        : {...m.toJson(), 'id': m.id};
    final data = await supabase
        .from('linkedin_metrics')
        .upsert(payload)
        .select()
        .single();
    return LinkedinMetrics.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('linkedin_metrics').delete().eq('id', id);
  }
}
