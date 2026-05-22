class Narrative {
  final String id;
  final String title;
  final String content;
  final String type;
  final String? context;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  const Narrative({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.context,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Narrative.fromJson(Map<String, dynamic> json) => Narrative(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        type: json['type'] as String,
        context: json['context'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'type': type,
        'context': context,
        'is_active': isActive,
      };
}
