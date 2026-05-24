class SquadRunModel {
  final String id;
  final String squadSlug;
  final String? squadName;
  final String initialPrompt;
  final String status;
  final String? createdAt;
  final String? completedAt;

  const SquadRunModel({
    required this.id,
    required this.squadSlug,
    this.squadName,
    required this.initialPrompt,
    required this.status,
    this.createdAt,
    this.completedAt,
  });

  factory SquadRunModel.fromJson(Map<String, dynamic> json) {
    return SquadRunModel(
      id: json['id'] as String,
      squadSlug: json['squad_slug'] as String,
      squadName: json['squad_name'] as String?,
      initialPrompt: json['initial_prompt'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String?,
      completedAt: json['completed_at'] as String?,
    );
  }
}
