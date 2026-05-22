class FlowModel {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final List<String> moduleSlugs;
  final String? createdAt;

  const FlowModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.moduleSlugs,
    this.createdAt,
  });

  factory FlowModel.fromJson(Map<String, dynamic> json) {
    final raw = json['module_slugs'];
    List<String> slugs;
    if (raw is List) {
      slugs = raw.cast<String>();
    } else if (raw is String) {
      slugs = raw.trim().isEmpty ? [] : raw.trim().split(RegExp(r'\s+'));
    } else {
      slugs = [];
    }
    return FlowModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      moduleSlugs: slugs,
      createdAt: json['created_at'] as String?,
    );
  }
}
