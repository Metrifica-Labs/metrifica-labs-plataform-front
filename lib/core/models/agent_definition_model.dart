class AgentDefinitionModel {
  final String id;
  final String slug;
  final String name;
  final String role;
  final String systemPrompt;
  final String llmProvider;
  final String llmModel;
  final List<String> toolNames;
  final String? createdAt;

  const AgentDefinitionModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.role,
    required this.systemPrompt,
    required this.llmProvider,
    required this.llmModel,
    this.toolNames = const [],
    this.createdAt,
  });

  factory AgentDefinitionModel.fromJson(Map<String, dynamic> json) {
    final rawTools = json['tools'];
    final toolNames = <String>[];
    if (rawTools is List) {
      for (final t in rawTools) {
        if (t is Map) {
          final fn = t['function'];
          if (fn is Map && fn['name'] is String) {
            toolNames.add(fn['name'] as String);
          }
        }
      }
    }
    return AgentDefinitionModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      systemPrompt: json['system_prompt'] as String,
      llmProvider: json['llm_provider'] as String? ?? 'crofai',
      llmModel: json['llm_model'] as String? ?? 'deepseek-v4-pro',
      toolNames: toolNames,
      createdAt: json['created_at'] as String?,
    );
  }
}
