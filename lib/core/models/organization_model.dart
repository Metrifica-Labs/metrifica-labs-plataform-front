class OrganizationModel {
  final String id;
  final String slug;
  final String name;
  final List<String> enabledFeatures;

  const OrganizationModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.enabledFeatures,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>? ?? {};
    final features =
        (config['enabled_features'] as List<dynamic>? ?? []).cast<String>();
    return OrganizationModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      enabledFeatures: features,
    );
  }

  bool hasFeature(String feature) => enabledFeatures.contains(feature);
}
