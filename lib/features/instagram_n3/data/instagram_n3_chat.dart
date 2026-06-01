import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/supabase/supabase_client.dart' as config;
import 'instagram_n3_card.dart';

enum N3ChatRole { user, assistant }

class N3ChatMessage {
  final String id;
  final N3ChatRole role;
  final String content;
  final N3Post? post;
  final bool isStreaming;
  final DateTime createdAt;

  const N3ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.post,
    this.isStreaming = false,
    required this.createdAt,
  });

  N3ChatMessage copyWith({
    String? content,
    N3Post? post,
    bool? isStreaming,
    bool clearPost = false,
  }) =>
      N3ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        post: clearPost ? null : (post ?? this.post),
        isStreaming: isStreaming ?? this.isStreaming,
        createdAt: createdAt,
      );
}

class N3ChatState {
  final List<N3ChatMessage> messages;
  final bool isGenerating;
  final String? error;

  const N3ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.error,
  });

  bool get isEmpty => messages.isEmpty;

  N3ChatState copyWith({
    List<N3ChatMessage>? messages,
    bool? isGenerating,
    String? error,
  }) =>
      N3ChatState(
        messages: messages ?? this.messages,
        isGenerating: isGenerating ?? this.isGenerating,
        error: error,
      );
}

const _kFlowSlug = 'instagram-n3';

final n3ChatProvider =
    StateNotifierProvider<N3ChatNotifier, N3ChatState>(
  (ref) => N3ChatNotifier(),
);

class N3ChatNotifier extends StateNotifier<N3ChatState> {
  N3ChatNotifier() : super(const N3ChatState());

  http.Client? _client;

  Future<void> send(String userText) async {
    final trimmed = userText.trim();
    if (state.isGenerating || trimmed.isEmpty) return;

    final now = DateTime.now();
    final userMsg = N3ChatMessage(
      id: '${now.millisecondsSinceEpoch}',
      role: N3ChatRole.user,
      content: trimmed,
      createdAt: now,
    );
    final assistantId = '${now.millisecondsSinceEpoch + 1}';
    final assistantMsg = N3ChatMessage(
      id: assistantId,
      role: N3ChatRole.assistant,
      content: '',
      isStreaming: true,
      createdAt: now,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isGenerating: true,
    );

    await _stream(assistantId);
  }

  Future<void> _stream(String assistantId) async {
    _client?.close();
    _client = http.Client();

    final apiMessages = state.messages
        .where((m) => !m.isStreaming)
        .map((m) => {
              'role': m.role == N3ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/run-flow');
    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${config.supabaseAnonKey}'
      ..headers['apikey'] = config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'flow_slug': _kFlowSlug,
        'messages': apiMessages,
      });

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        _setError('Erro ${response.statusCode}: $body', assistantId);
        return;
      }

      String buffer = '';

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(const Duration(seconds: 35),
              onTimeout: (sink) => sink.close())) {
        if (!mounted) return;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (final line in lines.take(lines.length - 1)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed == 'data: [DONE]') {
            _finalize(assistantId);
            return;
          }
          if (!trimmed.startsWith('data: ')) continue;
          try {
            final json =
                jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
            final type = json['type'] as String?;
            if (type == 'text') {
              _append(assistantId, json['text'] as String? ?? '');
            } else if (type == 'error') {
              _setError(
                  json['message'] as String? ?? 'Erro desconhecido',
                  assistantId);
              return;
            }
          } catch (_) {}
        }
      }

      if (mounted) _finalize(assistantId);
    } catch (e) {
      if (mounted) _setError(e.toString(), assistantId);
    }
  }

  void _append(String id, String text) {
    final msgs = state.messages.map((m) {
      if (m.id != id) return m;
      return m.copyWith(content: m.content + text);
    }).toList();
    state = state.copyWith(messages: msgs);
  }

  void _finalize(String id) {
    final msgs = state.messages.map((m) {
      if (m.id != id) return m;
      final parsed = parseN3Post(m.content);
      return m.copyWith(
        isStreaming: false,
        post: parsed.hasCards ? parsed : null,
        clearPost: !parsed.hasCards,
      );
    }).toList();
    state = state.copyWith(messages: msgs, isGenerating: false);
  }

  void _setError(String error, String assistantId) {
    final msgs = state.messages.map((m) {
      if (m.id != assistantId) return m;
      return m.copyWith(
        content: 'Não foi possível gerar a resposta. Tente novamente.',
        isStreaming: false,
      );
    }).toList();
    state =
        state.copyWith(messages: msgs, isGenerating: false, error: error);
  }

  void clear() {
    _client?.close();
    _client = null;
    state = const N3ChatState();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
