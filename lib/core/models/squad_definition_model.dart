class SquadDefinitionModel {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final List<String> agentSlugs;
  final String? createdAt;

  const SquadDefinitionModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.agentSlugs,
    this.createdAt,
  });

  factory SquadDefinitionModel.fromJson(Map<String, dynamic> json) {
    final raw = json['agent_slugs'];
    List<String> slugs;
    if (raw is List) {
      slugs = raw.cast<String>();
    } else if (raw is String) {
      slugs = raw.trim().isEmpty ? [] : raw.trim().split(RegExp(r'\s+'));
    } else {
      slugs = [];
    }
    return SquadDefinitionModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      agentSlugs: slugs,
      createdAt: json['created_at'] as String?,
    );
  }
}
