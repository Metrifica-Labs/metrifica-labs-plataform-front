import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'post_model.dart';

final postsProvider = FutureProvider<List<Post>>((ref) async {
  final data = await supabase
      .from('posts')
      .select()
      .order('created_at', ascending: false);
  return (data as List).map((e) => Post.fromJson(e)).toList();
});

final postsRepoProvider = Provider<PostsRepository>((ref) => PostsRepository());

class PostsRepository {
  Future<Post> upsert(Post post) async {
    final payload = post.id.isEmpty
        ? post.toJson()
        : {...post.toJson(), 'id': post.id};
    final data =
        await supabase.from('posts').upsert(payload).select().single();
    return Post.fromJson(data);
  }

  Future<void> delete(String id) async {
    await supabase.from('posts').delete().eq('id', id);
  }
}
