import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/providers/organization_provider.dart';
import '../../../core/supabase/supabase_client.dart' as config;
import '../../../core/supabase/supabase_client.dart' show supabase;
import 'personas_repository.dart';

enum CopyChatRole { user, assistant }

class CopyChatMessage {
  final String id;
  final CopyChatRole role;
  final String content;
  final bool isStreaming;
  final DateTime createdAt;

  const CopyChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.isStreaming = false,
    required this.createdAt,
  });

  CopyChatMessage copyWith({String? content, bool? isStreaming}) =>
      CopyChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role == CopyChatRole.user ? 'user' : 'assistant',
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };

  factory CopyChatMessage.fromJson(Map<String, dynamic> j) => CopyChatMessage(
        id: (j['id'] as String?) ?? DateTime.now().millisecondsSinceEpoch.toString(),
        role: j['role'] == 'user' ? CopyChatRole.user : CopyChatRole.assistant,
        content: (j['content'] as String?) ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class CopyChatState {
  final List<CopyChatMessage> messages;
  final bool isGenerating;
  final String? error;
  final String? sessionId;
  final bool isLoadingSession;

  const CopyChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.error,
    this.sessionId,
    this.isLoadingSession = false,
  });

  bool get isEmpty => messages.isEmpty && !isLoadingSession;

  String? get lastAssistantContent {
    for (final m in messages.reversed) {
      if (m.role == CopyChatRole.assistant &&
          !m.isStreaming &&
          m.content.isNotEmpty) {
        return m.content;
      }
    }
    return null;
  }

  CopyChatState copyWith({
    List<CopyChatMessage>? messages,
    bool? isGenerating,
    String? error,
    bool clearError = false,
    String? sessionId,
    bool clearSessionId = false,
    bool? isLoadingSession,
  }) =>
      CopyChatState(
        messages: messages ?? this.messages,
        isGenerating: isGenerating ?? this.isGenerating,
        error: clearError ? null : (error ?? this.error),
        sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
        isLoadingSession: isLoadingSession ?? this.isLoadingSession,
      );
}

class CopyChatNotifier extends StateNotifier<CopyChatState> {
  final String agentSlug;
  final String? personaContext;
  final String? orgId;
  final String? personaId;

  CopyChatNotifier({
    required this.agentSlug,
    this.personaContext,
    this.orgId,
    this.personaId,
  }) : super(const CopyChatState()) {
    if (orgId != null && personaId != null) {
      _loadLastSession();
    }
  }

  http.Client? _client;

  // ── Session persistence ────────────────────────────────────────────────────

  Future<void> _loadLastSession() async {
    if (!mounted) return;
    state = state.copyWith(isLoadingSession: true);
    try {
      final data = await supabase
          .from('copy_sessions')
          .select()
          .eq('org_id', orgId!)
          .eq('persona_id', personaId!)
          .eq('agent_slug', agentSlug)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted || data == null) {
        state = state.copyWith(isLoadingSession: false);
        return;
      }

      final rawMessages =
          (data['messages'] as List).cast<Map<String, dynamic>>();
      final messages =
          rawMessages.map(CopyChatMessage.fromJson).toList();

      state = state.copyWith(
        messages: messages,
        sessionId: data['id'] as String,
        isLoadingSession: false,
      );
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingSession: false);
    }
  }

  Future<void> _saveSession() async {
    if (orgId == null || personaId == null) return;
    final msgs = state.messages
        .where((m) => !m.isStreaming)
        .map((m) => m.toJson())
        .toList();
    if (msgs.isEmpty) return;

    try {
      if (state.sessionId == null) {
        final row = await supabase.from('copy_sessions').insert({
          'org_id': orgId,
          'persona_id': personaId,
          'agent_slug': agentSlug,
          'messages': msgs,
        }).select().single();
        if (mounted) {
          state = state.copyWith(sessionId: row['id'] as String);
        }
      } else {
        await supabase.from('copy_sessions').update({
          'messages': msgs,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', state.sessionId!);
      }
    } catch (_) {
      // auto-save falha silenciosamente
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<void> send(String userText) async {
    final trimmed = userText.trim();
    if (state.isGenerating || trimmed.isEmpty) return;

    final now = DateTime.now();
    final userMsg = CopyChatMessage(
      id: '${now.millisecondsSinceEpoch}',
      role: CopyChatRole.user,
      content: trimmed,
      createdAt: now,
    );
    final assistantId = '${now.millisecondsSinceEpoch + 1}';
    final assistantMsg = CopyChatMessage(
      id: assistantId,
      role: CopyChatRole.assistant,
      content: '',
      isStreaming: true,
      createdAt: now,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, assistantMsg],
      isGenerating: true,
      clearError: true,
    );

    await _stream(assistantId);
  }

  Future<void> _stream(String assistantId) async {
    _client?.close();
    _client = http.Client();

    final apiMessages = state.messages
        .where((m) => !(m.isStreaming && m.content.isEmpty))
        .map((m) => {
              'role': m.role == CopyChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    final body = <String, dynamic>{
      'agent_slug': agentSlug,
      'messages': apiMessages,
      if (personaContext != null) 'persona_context': personaContext,
    };

    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/run-agent');
    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${config.supabaseAnonKey}'
      ..headers['apikey'] = config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final respBody = await response.stream.bytesToString();
        _setError('Erro ${response.statusCode}: $respBody', assistantId);
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
      return m.copyWith(isStreaming: false);
    }).toList();
    state = state.copyWith(messages: msgs, isGenerating: false);
    _saveSession();
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
    // clearSessionId → próximo save cria nova sessão
    state = const CopyChatState();
  }

  Future<void> loadSession(String sessionId, List<CopyChatMessage> messages) async {
    state = state.copyWith(messages: messages, sessionId: sessionId);
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final avatarChatProvider =
    StateNotifierProvider<CopyChatNotifier, CopyChatState>(
  (ref) => CopyChatNotifier(agentSlug: 'copy-avatar'),
);

final toolsChatProvider =
    StateNotifierProvider<CopyChatNotifier, CopyChatState>((ref) {
  final persona = ref.watch(selectedPersonaProvider);
  final org = ref.watch(activeOrgProvider);
  return CopyChatNotifier(
    agentSlug: 'copy-tools',
    personaContext: persona?.content,
    orgId: org?.id,
    personaId: persona?.id,
  );
});

// Sessões históricas do personagem selecionado
final personaSessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final persona = ref.watch(selectedPersonaProvider);
  final org = ref.watch(activeOrgProvider);
  if (persona == null || org == null) return [];
  final data = await supabase
      .from('copy_sessions')
      .select('id, created_at, updated_at, messages')
      .eq('org_id', org.id)
      .eq('persona_id', persona.id)
      .eq('agent_slug', 'copy-tools')
      .order('updated_at', ascending: false)
      .limit(30);
  return (data as List).cast<Map<String, dynamic>>();
});
