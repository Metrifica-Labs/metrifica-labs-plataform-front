class PersonaModel {
  final String id;
  final String orgId;
  final String name;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonaModel({
    required this.id,
    required this.orgId,
    required this.name,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PersonaModel.fromJson(Map<String, dynamic> j) => PersonaModel(
        id: j['id'] as String,
        orgId: j['org_id'] as String,
        name: j['name'] as String,
        content: (j['content'] as String?) ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  @override
  bool operator ==(Object other) => other is PersonaModel && other.id == id;

  @override
  int get hashCode => id.hashCode;

  PersonaModel copyWith({String? name, String? content}) => PersonaModel(
        id: id,
        orgId: orgId,
        name: name ?? this.name,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
