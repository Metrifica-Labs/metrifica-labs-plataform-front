import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/agent_run_model.dart';
import '../../../core/models/squad_run_model.dart';
import '../../../core/supabase/supabase_client.dart';

// ─── Squad run com seus agent_runs carregados ─────────────────────────────────

class SquadRunDetail {
  final SquadRunModel run;
  final List<AgentRunModel> agentRuns;

  const SquadRunDetail({required this.run, required this.agentRuns});
}

// ─── Provider: lista de runs recentes ────────────────────────────────────────

final squadRunsHistoryProvider =
    AsyncNotifierProvider<SquadRunsHistoryNotifier, List<SquadRunModel>>(
  SquadRunsHistoryNotifier.new,
);

class SquadRunsHistoryNotifier
    extends AsyncNotifier<List<SquadRunModel>> {
  @override
  Future<List<SquadRunModel>> build() => _fetch();

  Future<List<SquadRunModel>> _fetch() async {
    final data = await supabase
        .from('squad_runs')
        .select()
        .order('created_at', ascending: false)
        .limit(30);
    return (data as List).map((e) => SquadRunModel.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> remove(String id) async {
    await supabase.from('squad_runs').delete().eq('id', id);
    state = AsyncData(
      state.value?.where((r) => r.id != id).toList() ?? [],
    );
  }
}

// ─── Provider: agent_runs de um squad_run específico ─────────────────────────

final agentRunsForSquadProvider =
    FutureProvider.family<List<AgentRunModel>, String>((ref, squadRunId) async {
  final data = await supabase
      .from('agent_runs')
      .select()
      .eq('squad_run_id', squadRunId)
      .order('step_index');
  return (data as List).map((e) => AgentRunModel.fromJson(e)).toList();
});
