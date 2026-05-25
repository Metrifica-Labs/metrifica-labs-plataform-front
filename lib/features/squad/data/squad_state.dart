enum SquadStatus { idle, connecting, running, done, error }

enum AgentRunStatus { pending, running, done, error }

class ToolCallState {
  final String tool;
  final String? result;

  const ToolCallState({required this.tool, this.result});

  bool get isPending => result == null;

  ToolCallState withResult(String r) => ToolCallState(tool: tool, result: r);
}

class AgentRunState {
  final String agentSlug;
  final String agentName;
  final int step;
  final AgentRunStatus status;
  final String thinking;
  final String output;
  final List<ToolCallState> toolCalls;

  const AgentRunState({
    required this.agentSlug,
    required this.agentName,
    required this.step,
    this.status = AgentRunStatus.pending,
    this.thinking = '',
    this.output = '',
    this.toolCalls = const [],
  });

  bool get isActive => status == AgentRunStatus.running;
  bool get isDone => status == AgentRunStatus.done;
  bool get hasOutput => output.isNotEmpty;
  bool get hasThinking => thinking.isNotEmpty;
  bool get hasToolCalls => toolCalls.isNotEmpty;

  AgentRunState copyWith({
    AgentRunStatus? status,
    String? thinking,
    String? output,
    List<ToolCallState>? toolCalls,
  }) => AgentRunState(
    agentSlug: agentSlug,
    agentName: agentName,
    step: step,
    status: status ?? this.status,
    thinking: thinking ?? this.thinking,
    output: output ?? this.output,
    toolCalls: toolCalls ?? this.toolCalls,
  );

  // Resolve o resultado da última tool call pendente com esse nome
  AgentRunState resolveToolCall(String toolName, String result) {
    bool resolved = false;
    final updated =
        toolCalls.map((tc) {
          if (!resolved && tc.tool == toolName && tc.isPending) {
            resolved = true;
            return tc.withResult(result);
          }
          return tc;
        }).toList();
    return copyWith(toolCalls: updated);
  }
}

class SquadState {
  final SquadStatus status;
  final String? squadName;
  final String? runId;
  final String? initialPrompt;
  final String? orchestratorThinking;
  final List<AgentRunState> agentRuns;
  final String? error;

  const SquadState({
    this.status = SquadStatus.idle,
    this.squadName,
    this.runId,
    this.initialPrompt,
    this.orchestratorThinking,
    this.agentRuns = const [],
    this.error,
  });

  bool get isRunning =>
      status == SquadStatus.connecting || status == SquadStatus.running;
  bool get isDone => status == SquadStatus.done;
  bool get hasAgents => agentRuns.isNotEmpty;

  AgentRunState? get activeAgent =>
      agentRuns.where((a) => a.isActive).lastOrNull;

  SquadState copyWith({
    SquadStatus? status,
    String? squadName,
    String? runId,
    String? initialPrompt,
    String? orchestratorThinking,
    List<AgentRunState>? agentRuns,
    String? error,
    bool clearError = false,
  }) => SquadState(
    status: status ?? this.status,
    squadName: squadName ?? this.squadName,
    runId: runId ?? this.runId,
    initialPrompt: initialPrompt ?? this.initialPrompt,
    orchestratorThinking: orchestratorThinking ?? this.orchestratorThinking,
    agentRuns: agentRuns ?? this.agentRuns,
    error: clearError ? null : error ?? this.error,
  );

  SquadState updateActiveAgent(
    String agentSlug,
    AgentRunState Function(AgentRunState) updater,
  ) {
    return copyWith(
      agentRuns:
          agentRuns
              .map(
                (a) =>
                    (a.agentSlug == agentSlug && a.isActive) ? updater(a) : a,
              )
              .toList(),
    );
  }
}
