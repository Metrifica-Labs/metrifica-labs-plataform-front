class AgentRunModel {
  final String id;
  final String squadRunId;
  final String agentSlug;
  final String agentName;
  final int stepIndex;
  final String input;
  final String? output;
  final String status;
  final String? startedAt;
  final String? completedAt;

  const AgentRunModel({
    required this.id,
    required this.squadRunId,
    required this.agentSlug,
    required this.agentName,
    required this.stepIndex,
    required this.input,
    this.output,
    required this.status,
    this.startedAt,
    this.completedAt,
  });

  factory AgentRunModel.fromJson(Map<String, dynamic> json) {
    return AgentRunModel(
      id: json['id'] as String,
      squadRunId: json['squad_run_id'] as String,
      agentSlug: json['agent_slug'] as String,
      agentName: json['agent_name'] as String,
      stepIndex: json['step_index'] as int,
      input: json['input'] as String,
      output: json['output'] as String?,
      status: json['status'] as String,
      startedAt: json['started_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }
}
