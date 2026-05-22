import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'career_review_model.dart';

final careerReviewsProvider = FutureProvider<List<CareerReview>>((ref) async {
  final data = await supabase
      .from('career_reviews')
      .select()
      .order('year', ascending: false);
  return (data as List).map((e) => CareerReview.fromJson(e)).toList();
});

final careerReviewsRepoProvider =
    Provider<CareerReviewsRepository>((ref) => CareerReviewsRepository());

class CareerReviewsRepository {
  Future<CareerReview> upsert(CareerReview r) async {
    final payload =
        r.id.isEmpty ? r.toJson() : {...r.toJson(), 'id': r.id};
    final data = await supabase
        .from('career_reviews')
        .upsert(payload)
        .select()
        .single();
    return CareerReview.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('career_reviews').delete().eq('id', id);
  }
}
