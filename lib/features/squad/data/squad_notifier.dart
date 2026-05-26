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
  bool _cancelled = false;

  Future<void> run({
    required String squadSlug,
    required String userMessage,
    String? organizationId,
  }) async {
    _resetClient();
    state = SquadState(
      status: SquadStatus.connecting,
      initialPrompt: userMessage,
    );

    try {
      final run = await _startRun(
        squadSlug: squadSlug,
        userMessage: userMessage,
        organizationId: organizationId,
      );
      state = state.copyWith(
        status: SquadStatus.running,
        squadName: run.squadName,
        runId: run.id,
        initialPrompt: run.initialPrompt,
      );
      await _driveRun(run.id);
    } catch (e) {
      if (mounted && !_cancelled) {
        state = state.copyWith(status: SquadStatus.error, error: e.toString());
      }
    }
  }

  Future<void> resume({
    required String squadSlug,
    required String userMessage,
    required String runId,
  }) async {
    _resetClient();
    state = state.copyWith(status: SquadStatus.connecting, clearError: true);
    await _driveRun(runId);
  }

  Future<SquadRunModel> _startRun({
    required String squadSlug,
    required String userMessage,
    String? organizationId,
  }) async {
    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/start-squad-run');
    final res = await _client!.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'squad_slug': squadSlug,
        'user_message': userMessage,
        if (organizationId != null) 'organization_id': organizationId,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ${res.statusCode}: ${res.body}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return SquadRunModel.fromJson(json['run'] as Map<String, dynamic>);
  }

  Future<void> _driveRun(String runId) async {
    var requestedStep = false;

    while (mounted && !_cancelled) {
      final snapshot = await _fetchSnapshot(runId);
      _applySnapshot(snapshot.run, snapshot.agentRuns);

      if (snapshot.run.status == 'done' || snapshot.run.status == 'error') {
        return;
      }

      final hasRunningAgent = snapshot.agentRuns.any(
        (a) => a.status == 'running',
      );
      if (!hasRunningAgent && !requestedStep) {
        requestedStep = true;
        await _queueStep(runId);
      }

      if (hasRunningAgent) requestedStep = false;
      await Future<void>.delayed(Duration(seconds: hasRunningAgent ? 5 : 3));
    }
  }

  Future<_SquadSnapshot> _fetchSnapshot(String runId) async {
    final runJson =
        await config.supabase
            .from('squad_runs')
            .select()
            .eq('id', runId)
            .single();

    final agentRows = await config.supabase
        .from('agent_runs')
        .select()
        .eq('squad_run_id', runId)
        .order('step_index');

    return _SquadSnapshot(
      run: SquadRunModel.fromJson(runJson),
      agentRuns:
          (agentRows as List)
              .map((e) => AgentRunModel.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Future<void> _queueStep(String runId) async {
    final uri = Uri.parse('${config.supabaseUrl}/functions/v1/run-squad-step');
    final res = await _client!.post(
      uri,
      headers: _headers,
      body: jsonEncode({'run_id': runId}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Erro ao agendar etapa ${res.statusCode}: ${res.body}');
    }
  }

  void _applySnapshot(SquadRunModel run, List<AgentRunModel> agentRuns) {
    final agents =
        agentRuns
            .map(
              (r) => AgentRunState(
                agentSlug: r.agentSlug,
                agentName: r.agentName,
                step: r.stepIndex,
                status: switch (r.status) {
                  'done' => AgentRunStatus.done,
                  'running' => AgentRunStatus.running,
                  _ => AgentRunStatus.error,
                },
                thinking:
                    r.status == 'running'
                        ? 'Executando em background. A página só acompanha o estado salvo; a geração não depende desta conexão.'
                        : '',
                output: r.output ?? '',
              ),
            )
            .toList();

    state = state.copyWith(
      status: switch (run.status) {
        'done' => SquadStatus.done,
        'error' => SquadStatus.error,
        _ => SquadStatus.running,
      },
      squadName: run.squadName,
      runId: run.id,
      initialPrompt: run.initialPrompt,
      agentRuns: agents,
      error: run.status == 'error' ? 'Execução encerrada com erro.' : null,
      clearError: run.status != 'error',
    );
  }

  void restore({
    required SquadRunModel run,
    required List<AgentRunModel> agentRuns,
  }) {
    _applySnapshot(run, agentRuns);
  }

  void clear() {
    _cancelled = true;
    _client?.close();
    _client = null;
    state = const SquadState();
  }

  void _resetClient() {
    _cancelled = false;
    _client?.close();
    _client = http.Client();
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${config.supabaseAnonKey}',
    'apikey': config.supabaseAnonKey,
    'Content-Type': 'application/json',
  };

  @override
  void dispose() {
    _cancelled = true;
    _client?.close();
    super.dispose();
  }
}

class _SquadSnapshot {
  final SquadRunModel run;
  final List<AgentRunModel> agentRuns;

  const _SquadSnapshot({required this.run, required this.agentRuns});
}
