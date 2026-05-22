class Post {
  final String id;
  final String content;
  final String? title;
  final String status;
  final String type;
  final String? pillar;
  final String? imagePrompt;
  final String? publishedAt;
  final int? impressions;
  final int? reactions;
  final int? comments;
  final int? reposts;
  final String? createdAt;
  final String? updatedAt;

  const Post({
    required this.id,
    required this.content,
    this.title,
    required this.status,
    required this.type,
    this.pillar,
    this.imagePrompt,
    this.publishedAt,
    this.impressions,
    this.reactions,
    this.comments,
    this.reposts,
    this.createdAt,
    this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        content: json['content'] as String,
        title: json['title'] as String?,
        status: json['status'] as String? ?? 'draft',
        type: json['type'] as String? ?? 'general',
        pillar: json['pillar'] as String?,
        imagePrompt: json['image_prompt'] as String?,
        publishedAt: json['published_at'] as String?,
        impressions: json['impressions'] as int?,
        reactions: json['reactions'] as int?,
        comments: json['comments'] as int?,
        reposts: json['reposts'] as int?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'content': content,
        'title': title,
        'status': status,
        'type': type,
        'pillar': pillar,
        'image_prompt': imagePrompt,
        'published_at': publishedAt,
        'impressions': impressions,
        'reactions': reactions,
        'comments': comments,
        'reposts': reposts,
      };
}
