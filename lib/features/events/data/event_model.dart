class Event {
  final String id;
  final String name;
  final String type;
  final String? theme;
  final String? date;
  final String? location;
  final int? audienceSize;
  final String? postId;
  final String? notes;
  final String? createdAt;

  const Event({
    required this.id,
    required this.name,
    required this.type,
    this.theme,
    this.date,
    this.location,
    this.audienceSize,
    this.postId,
    this.notes,
    this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String? ?? 'attendance',
        theme: json['theme'] as String?,
        date: json['date'] as String?,
        location: json['location'] as String?,
        audienceSize: json['audience_size'] as int?,
        postId: json['post_id'] as String?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'theme': theme,
        'date': date,
        'location': location,
        'audience_size': audienceSize,
        'post_id': postId,
        'notes': notes,
      };
}
