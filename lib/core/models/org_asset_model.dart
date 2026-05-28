class OrgAssetModel {
  final String id;
  final String organizationId;
  final String name;
  final String storagePath;
  final String? publicUrl;
  final String assetType;
  // Referência usada no markdown: {{asset:logo}}
  final String? alias;
  final DateTime createdAt;

  const OrgAssetModel({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.storagePath,
    this.publicUrl,
    required this.assetType,
    this.alias,
    required this.createdAt,
  });

  factory OrgAssetModel.fromJson(Map<String, dynamic> json) => OrgAssetModel(
        id: json['id'] as String,
        organizationId: json['organization_id'] as String,
        name: json['name'] as String,
        storagePath: json['storage_path'] as String,
        publicUrl: json['public_url'] as String?,
        assetType: json['asset_type'] as String? ?? 'image',
        alias: json['alias'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
