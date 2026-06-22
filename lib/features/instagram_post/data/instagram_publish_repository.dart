import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart' as config;
import '../../../core/supabase/supabase_client.dart';
import '../../editorial/data/post_model.dart';
import '../../editorial/data/posts_repository.dart';

const kInstagramFlowSlug = 'instagram-text-post';

class InstagramPublishRepository {
  InstagramPublishRepository(this._postsRepo);

  final PostsRepository _postsRepo;

  String get _userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) throw Exception('Usuário não autenticado');
    return id;
  }

  String get _userJwt {
    final jwt = supabase.auth.currentSession?.accessToken;
    if (jwt == null) throw Exception('Usuário não autenticado');
    return jwt;
  }

  Future<String> _uploadImage(Uint8List bytes) async {
    final path = '$_userId/${DateTime.now().microsecondsSinceEpoch}.png';
    await supabase.storage.from('instagram-publish-media').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
    return supabase.storage.from('instagram-publish-media').getPublicUrl(path);
  }

  /// Cria o post (draft ou já agendado) e, se [scheduledAt] for null, dispara
  /// a publicação imediata via edge function. A publicação sempre usa a
  /// conexão Instagram do usuário logado — quem cria o post é quem publica.
  /// [imagesBytes] com mais de 1 item publica como carrossel (na ordem dos
  /// slides); a primeira imagem é gravada também como capa (image_url).
  Future<PostModel> publish({
    required String orgId,
    required List<Uint8List> imagesBytes,
    required String caption,
    DateTime? scheduledAt,
  }) async {
    final imageUrls = <String>[];
    for (final bytes in imagesBytes) {
      imageUrls.add(await _uploadImage(bytes));
    }

    final post = await _postsRepo.createDraft(
      orgId: orgId,
      flowSlug: kInstagramFlowSlug,
      content: caption,
      imageUrl: imageUrls.first,
      imageUrls: imageUrls,
      status: scheduledAt != null ? PostStatus.scheduled : PostStatus.draft,
      scheduledAt: scheduledAt,
    );

    if (scheduledAt == null) {
      await _publishNow(post.id);
    }

    return post;
  }

  Future<void> _publishNow(String postId) async {
    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/publish-instagram-post');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_userJwt',
        'apikey': config.supabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'post_id': postId}),
    );

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || json['ok'] != true) {
      throw Exception(json['error'] as String? ?? 'Falha ao publicar no Instagram');
    }
  }
}

final instagramPublishRepositoryProvider = Provider<InstagramPublishRepository>(
  (ref) => InstagramPublishRepository(ref.read(postsRepositoryProvider)),
);
