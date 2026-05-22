import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'certification_model.dart';

final certificationsProvider = FutureProvider<List<Certification>>((ref) async {
  final data = await supabase
      .from('certifications')
      .select()
      .order('priority_order');
  return (data as List).map((e) => Certification.fromJson(e)).toList();
});

final studyProgressProvider =
    FutureProvider.family<List<StudyProgress>, String>((ref, certId) async {
  final data = await supabase
      .from('study_progress')
      .select()
      .eq('certification_id', certId)
      .order('week_start', ascending: false);
  return (data as List).map((e) => StudyProgress.fromJson(e)).toList();
});

final certificationsRepoProvider =
    Provider<CertificationsRepository>((ref) => CertificationsRepository());

class CertificationsRepository {
  Future<Certification> upsert(Certification cert) async {
    final payload = {...cert.toJson(), 'id': cert.id};
    final data = await supabase
        .from('certifications')
        .upsert(payload)
        .select()
        .single();
    return Certification.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('certifications').delete().eq('id', id);
  }

  Future<StudyProgress> addProgress(StudyProgress progress) async {
    final data = await supabase
        .from('study_progress')
        .insert(progress.toJson())
        .select()
        .single();
    return StudyProgress.fromJson(data);
  }

  Future<void> deleteProgress(String id) async {
    await supabase.from('study_progress').delete().eq('id', id);
  }
}
