import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_client.dart' as config;
import '../../../core/supabase/supabase_client.dart';

enum InstagramConnectionStatus { none, pending, active, error }

class InstagramConnectionState {
  final InstagramConnectionStatus status;
  final String? igUsername;

  const InstagramConnectionState({
    this.status = InstagramConnectionStatus.none,
    this.igUsername,
  });
}

/// Estado da conexão Instagram do usuário logado. É sempre por usuário —
/// nunca exibe ou usa a conexão de outro membro da organização.
final instagramConnectionProvider =
    FutureProvider.autoDispose<InstagramConnectionState>((ref) async {
  final data = await supabase
      .from('instagram_connections')
      .select('status, ig_username')
      .maybeSingle();
  if (data == null) return const InstagramConnectionState();

  final status = switch (data['status'] as String?) {
    'active' => InstagramConnectionStatus.active,
    'pending' => InstagramConnectionStatus.pending,
    'error' => InstagramConnectionStatus.error,
    _ => InstagramConnectionStatus.none,
  };
  return InstagramConnectionState(
    status: status,
    igUsername: data['ig_username'] as String?,
  );
});

class InstagramConnectionRepository {
  Map<String, String> _authHeaders(String jwt) => {
        'Authorization': 'Bearer $jwt',
        'apikey': config.supabaseAnonKey,
        'Content-Type': 'application/json',
      };

  String get _userJwt {
    final jwt = supabase.auth.currentSession?.accessToken;
    if (jwt == null) throw Exception('Usuário não autenticado');
    return jwt;
  }

  /// Inicia a autorização OAuth do Instagram para o usuário logado e
  /// devolve a URL para o usuário visitar e autorizar a própria conta.
  Future<String> startConnect() async {
    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/instagram-connect');
    final res = await http.post(uri, headers: _authHeaders(_userJwt));
    if (res.statusCode != 200) {
      throw Exception('Erro ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['redirect_url'] as String;
  }

  /// Consulta o status atual da conexão do usuário logado (após o popup de
  /// autorização) e sincroniza ig_user_id/username no banco.
  Future<InstagramConnectionStatus> checkStatus() async {
    final uri =
        Uri.parse('${config.supabaseUrl}/functions/v1/instagram-connect-status');
    final res = await http.post(uri, headers: _authHeaders(_userJwt));
    if (res.statusCode != 200) {
      throw Exception('Erro ${res.statusCode}: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return switch (json['status'] as String?) {
      'active' => InstagramConnectionStatus.active,
      'error' => InstagramConnectionStatus.error,
      'none' => InstagramConnectionStatus.none,
      _ => InstagramConnectionStatus.pending,
    };
  }
}

final instagramConnectionRepositoryProvider =
    Provider<InstagramConnectionRepository>(
        (ref) => InstagramConnectionRepository());
