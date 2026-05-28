import 'package:flutter/material.dart';

enum PostStatus {
  draft,
  approved,
  scheduled,
  published;

  String get label => switch (this) {
        PostStatus.draft => 'Rascunho',
        PostStatus.approved => 'Aprovado',
        PostStatus.scheduled => 'Agendado',
        PostStatus.published => 'Publicado',
      };

  Color get color => switch (this) {
        PostStatus.draft => Colors.grey,
        PostStatus.approved => Colors.blue,
        PostStatus.scheduled => Colors.orange,
        PostStatus.published => Colors.green,
      };

  static PostStatus fromString(String v) => switch (v) {
        'approved' => PostStatus.approved,
        'scheduled' => PostStatus.scheduled,
        'published' => PostStatus.published,
        _ => PostStatus.draft,
      };
}

class PostModel {
  final String id;
  final String organizationId;
  final String flowSlug;
  final String content;
  final String? imageUrl;
  final PostStatus status;
  final String? pillar;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostModel({
    required this.id,
    required this.organizationId,
    required this.flowSlug,
    required this.content,
    this.imageUrl,
    required this.status,
    this.pillar,
    this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) => PostModel(
        id: json['id'] as String,
        organizationId: json['organization_id'] as String,
        flowSlug: json['flow_slug'] as String,
        content: json['content'] as String,
        imageUrl: json['image_url'] as String?,
        status: PostStatus.fromString(json['status'] as String? ?? 'draft'),
        pillar: json['pillar'] as String?,
        scheduledAt: json['scheduled_at'] == null
            ? null
            : DateTime.parse(json['scheduled_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'flow_slug': flowSlug,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        'status': status.name,
        if (pillar != null) 'pillar': pillar,
        if (scheduledAt != null) 'scheduled_at': scheduledAt!.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  PostModel copyWith({
    String? imageUrl,
    PostStatus? status,
    DateTime? scheduledAt,
  }) =>
      PostModel(
        id: id,
        organizationId: organizationId,
        flowSlug: flowSlug,
        content: content,
        imageUrl: imageUrl ?? this.imageUrl,
        status: status ?? this.status,
        pillar: pillar,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
