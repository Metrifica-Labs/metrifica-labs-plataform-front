class ProposalTemplateModel {
  final String id;
  final String slug;
  final String name;
  final String? content;
  final String? promptScaffold;
  final String? flowSlug;
  final String? createdAt;
  final String? updatedAt;

  const ProposalTemplateModel({
    required this.id,
    required this.slug,
    required this.name,
    this.content,
    this.promptScaffold,
    this.flowSlug,
    this.createdAt,
    this.updatedAt,
  });

  factory ProposalTemplateModel.fromJson(Map<String, dynamic> json) =>
      ProposalTemplateModel(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        content: json['content'] as String?,
        promptScaffold: json['prompt_scaffold'] as String?,
        flowSlug: json['flow_slug'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );
}
