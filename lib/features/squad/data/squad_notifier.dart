import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/agent_run_model.dart';
import '../../../core/models/squad_run_model.dart';
import '../../../core/supabase/supabase_client.dart' as config;
import 'squad_state.dart';

final squadProvider =
    StateNotifierProvider.autoDispose<SquadNotifier, SquadState>(
  (ref) => SquadNotifier(),
);

class SquadNotifier extends StateNotifier<SquadState> {
  SquadNotifier() : super(const SquadState());

  http.Client? _client;

  Future<void> run({
    required String squadSlug,
    required String userMessage,
  }) async {
    _client?.close();
    _client = http.Client();

    state = SquadState(
      status: SquadStatus.connecting,
      initialPrompt: userMessage,
    );

    await _stream(
      squadSlug: squadSlug,
      userMessage: userMessage,
      resumeRunId: null,
    );
  }

  Future<void> resume({
    required String squadSlug,
    required String userMessage,
    required String runId,
  }) async {
    _client?.close();
    _client = http.Client();

    // Mantém agents existentes visíveis, só troca o status
    state = state.copyWith(
      status: SquadStatus.connecting,
      error: null,
    );

    await _stream(
      squadSlug: squadSlug,
      userMessage: userMessage,
      resumeRunId: runId,
    );
  }

  Future<void> _stream({
    required String squadSlug,
    required String userMessage,
    required String? resumeRunId,
  }) async {
    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/run-squad');

    final body = <String, dynamic>{
      'squad_slug': squadSlug,
      'user_message': userMessage,
    };
    if (resumeRunId != null) body['resume_run_id'] = resumeRunId;

    final request = http.Request('POST', uri)
      ..headers['Authorization'] = 'Bearer ${config.supabaseAnonKey}'
      ..headers['apikey'] = config.supabaseAnonKey
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(body);

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final responseBody = await response.stream.bytesToString();
        state = state.copyWith(
          status: SquadStatus.error,
          error: 'Erro ${response.statusCode}: $responseBody',
        );
        return;
      }

      String buffer = '';
      const chunkTimeout = Duration(seconds: 120);

      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .timeout(chunkTimeout, onTimeout: (sink) => sink.close())) {
        if (!mounted) return;

        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (final line in lines.take(lines.length - 1)) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (trimmed == 'data: [DONE]') {
            if (state.status != SquadStatus.done) {
              state = state.copyWith(status: SquadStatus.done);
            }
            return;
          }
          if (!trimmed.startsWith('data: ')) continue;

          try {
            final json =
                jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
            _handleEvent(json);
          } catch (_) {
            // linha malformada, ignora
          }
        }
      }

      if (mounted && state.status != SquadStatus.done) {
        state = state.copyWith(status: SquadStatus.done);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          status: SquadStatus.error,
          error: e.toString(),
        );
      }
    }
  }

  void _handleEvent(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    switch (type) {
      case 'squad_start':
        // Em resume, só atualiza status e nome sem limpar agents existentes
        state = state.copyWith(
          status: SquadStatus.running,
          squadName: json['squad'] as String?,
          runId: json['run_id'] as String?,
        );
      case 'orchestrator_thinking':
        state = state.copyWith(
          orchestratorThinking: json['text'] as String?,
        );
      case 'agent_start':
        final agentSlug = json['agent_slug'] as String;
        final agentName = json['agent'] as String;
        final step = json['step'] as int? ?? state.agentRuns.length;
        state = state.copyWith(
          agentRuns: [
            ...state.agentRuns,
            AgentRunState(
              agentSlug: agentSlug,
              agentName: agentName,
              step: step,
              status: AgentRunStatus.running,
            ),
          ],
        );
      case 'thinking':
        final agentSlug = json['agent_slug'] as String?;
        final text = json['text'] as String? ?? '';
        if (agentSlug != null) {
          state = state.updateActiveAgent(
            agentSlug,
            (a) => a.copyWith(thinking: a.thinking + text),
          );
        }
      case 'text':
        final agentSlug = json['agent_slug'] as String?;
        final text = json['text'] as String? ?? '';
        if (agentSlug != null) {
          state = state.updateActiveAgent(
            agentSlug,
            (a) => a.copyWith(output: a.output + text),
          );
        }
      case 'tool_call':
        final agentSlug = json['agent_slug'] as String?;
        final tool = json['tool'] as String? ?? '';
        if (agentSlug != null) {
          state = state.updateActiveAgent(
            agentSlug,
            (a) => a.copyWith(
              toolCalls: [...a.toolCalls, ToolCallState(tool: tool)],
            ),
          );
        }
      case 'tool_result':
        final agentSlug = json['agent_slug'] as String?;
        final tool = json['tool'] as String? ?? '';
        final result = json['result'] as String? ?? '';
        if (agentSlug != null) {
          state = state.updateActiveAgent(
            agentSlug,
            (a) => a.resolveToolCall(tool, result),
          );
        }
      case 'agent_done':
        final agentSlug = json['agent_slug'] as String?;
        if (agentSlug != null) {
          state = state.updateActiveAgent(
            agentSlug,
            (a) => a.copyWith(status: AgentRunStatus.done),
          );
        }
      case 'squad_done':
        state = state.copyWith(status: SquadStatus.done);
      case 'error':
        state = state.copyWith(
          status: SquadStatus.error,
          error: json['message'] as String? ?? 'Erro desconhecido',
        );
    }
  }

  void restore({
    required SquadRunModel run,
    required List<AgentRunModel> agentRuns,
  }) {
    final agents = agentRuns
        .map((r) => AgentRunState(
              agentSlug: r.agentSlug,
              agentName: r.agentName,
              step: r.stepIndex,
              status: r.status == 'done'
                  ? AgentRunStatus.done
                  : AgentRunStatus.error,
              output: r.output ?? '',
            ))
        .toList()
      ..sort((a, b) => a.step.compareTo(b.step));

    state = SquadState(
      status: run.status == 'done' ? SquadStatus.done : SquadStatus.error,
      squadName: run.squadName,
      runId: run.id,
      initialPrompt: run.initialPrompt,
      agentRuns: agents,
    );
  }

  void clear() {
    _client?.close();
    _client = null;
    state = const SquadState();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
