import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'career_profile_model.dart';

final careerProfileRepositoryProvider =
    Provider<CareerProfileRepository>((ref) => CareerProfileRepository());

final careerProfileProvider = FutureProvider<CareerProfile?>((ref) async {
  return ref.read(careerProfileRepositoryProvider).fetch();
});

class CareerProfileRepository {
  Future<CareerProfile?> fetch() async {
    final data = await supabase
        .from('career_profile')
        .select()
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return CareerProfile.fromJson(data);
  }

  Future<CareerProfile> upsert(CareerProfile profile) async {
    final data = await supabase
        .from('career_profile')
        .upsert({...profile.toJson(), 'id': profile.id})
        .select()
        .single();
    return CareerProfile.fromJson(data);
  }
}
