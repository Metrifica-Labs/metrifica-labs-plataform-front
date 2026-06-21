import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/organization_provider.dart';
import '../../../core/supabase/supabase_client.dart';
import 'post_model.dart';

final postsProvider = FutureProvider<List<PostModel>>((ref) async {
  final org = ref.watch(activeOrgProvider);
  if (org == null) return [];
  final data = await supabase
      .from('posts')
      .select()
      .eq('organization_id', org.id)
      .order('created_at', ascending: false)
      .limit(100);
  return (data as List).map((e) => PostModel.fromJson(e)).toList();
});

final postsForPillarStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final org = ref.watch(activeOrgProvider);
  if (org == null) return {};
  final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
  final data = await supabase
      .from('posts')
      .select('pillar')
      .eq('organization_id', org.id)
      .gte('created_at', since);
  final counts = <String, int>{};
  for (final row in data as List) {
    final p = (row['pillar'] as String?) ?? 'sem pilar';
    counts[p] = (counts[p] ?? 0) + 1;
  }
  return counts;
});

class PostsRepository {
  Future<PostModel> createDraft({
    required String orgId,
    required String flowSlug,
    required String content,
    String? imageUrl,
    String? pillar,
    PostStatus? status,
    DateTime? scheduledAt,
  }) async {
    final data = await supabase
        .from('posts')
        .insert({
          'organization_id': orgId,
          'flow_slug': flowSlug,
          'content': content,
          if (imageUrl != null) 'image_url': imageUrl,
          if (pillar != null) 'pillar': pillar,
          if (status != null) 'status': status.name,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
          'created_by': supabase.auth.currentUser?.id,
        })
        .select()
        .single();
    return PostModel.fromJson(data);
  }

  Future<PostModel> updateStatus(
    String id,
    PostStatus status, {
    DateTime? scheduledAt,
  }) async {
    final data = await supabase
        .from('posts')
        .update({
          'status': status.name,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return PostModel.fromJson(data);
  }

  Future<void> updateImageUrl(String id, String imageUrl) async {
    await supabase.from('posts').update({'image_url': imageUrl}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from('posts').delete().eq('id', id);
  }
}

final postsRepositoryProvider =
    Provider<PostsRepository>((ref) => PostsRepository());
