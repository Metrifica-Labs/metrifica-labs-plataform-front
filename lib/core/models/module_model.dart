class ModuleModel {
  final String id;
  final String slug;
  final String name;
  final String? content;
  final String? moduleRef;
  final String? updatedAt;
  final String? createdAt;

  const ModuleModel({
    required this.id,
    required this.slug,
    required this.name,
    this.content,
    this.moduleRef,
    this.updatedAt,
    this.createdAt,
  });

  factory ModuleModel.fromJson(Map<String, dynamic> json) => ModuleModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        content: json['content'] as String?,
        moduleRef: json['module_ref'] as String?,
        updatedAt: json['updated_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name': name,
        'content': content,
        'module_ref': moduleRef,
      };
}
