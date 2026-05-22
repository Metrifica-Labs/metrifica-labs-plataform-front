class Certification {
  final String id;
  final String name;
  final String? code;
  final String status;
  final int priorityOrder;
  final String? targetDate;
  final String? studyHoursDay;
  final List<String>? topics;
  final List<String>? resources;
  final String? notes;
  final String? completedAt;
  final String? createdAt;

  const Certification({
    required this.id,
    required this.name,
    this.code,
    required this.status,
    required this.priorityOrder,
    this.targetDate,
    this.studyHoursDay,
    this.topics,
    this.resources,
    this.notes,
    this.completedAt,
    this.createdAt,
  });

  factory Certification.fromJson(Map<String, dynamic> json) => Certification(
        id: json['id'] as String,
        name: json['name'] as String,
        code: json['code'] as String?,
        status: json['status'] as String? ?? 'not_started',
        priorityOrder: json['priority_order'] as int? ?? 0,
        targetDate: json['target_date'] as String?,
        studyHoursDay: json['study_hours_day'] as String?,
        topics: (json['topics'] as List?)?.cast<String>(),
        resources: (json['resources'] as List?)?.cast<String>(),
        notes: json['notes'] as String?,
        completedAt: json['completed_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'status': status,
        'priority_order': priorityOrder,
        'target_date': targetDate,
        'study_hours_day': studyHoursDay,
        'topics': topics,
        'resources': resources,
        'notes': notes,
      };
}

class StudyProgress {
  final String id;
  final String? certificationId;
  final String weekStart;
  final double? hours;
  final String? topicsStudied;
  final double? mockExamScore;
  final String? mockPlatform;
  final String? notes;
  final String? createdAt;

  const StudyProgress({
    required this.id,
    this.certificationId,
    required this.weekStart,
    this.hours,
    this.topicsStudied,
    this.mockExamScore,
    this.mockPlatform,
    this.notes,
    this.createdAt,
  });

  factory StudyProgress.fromJson(Map<String, dynamic> json) => StudyProgress(
        id: json['id'] as String,
        certificationId: json['certification_id'] as String?,
        weekStart: json['week_start'] as String,
        hours: (json['hours'] as num?)?.toDouble(),
        topicsStudied: json['topics_studied'] as String?,
        mockExamScore: (json['mock_exam_score'] as num?)?.toDouble(),
        mockPlatform: json['mock_platform'] as String?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'certification_id': certificationId,
        'week_start': weekStart,
        'hours': hours,
        'topics_studied': topicsStudied,
        'mock_exam_score': mockExamScore,
        'mock_platform': mockPlatform,
        'notes': notes,
      };
}
