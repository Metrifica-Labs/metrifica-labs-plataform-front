class CareerReview {
  final String id;
  final int year;
  final int quarter;
  final int? alignmentScore;
  final String? technicalProgress;
  final String? linkedinSummary;
  final String? opportunitiesSummary;
  final String? adjustmentsNeeded;
  final String? completedAt;
  final String? createdAt;

  const CareerReview({
    required this.id,
    required this.year,
    required this.quarter,
    this.alignmentScore,
    this.technicalProgress,
    this.linkedinSummary,
    this.opportunitiesSummary,
    this.adjustmentsNeeded,
    this.completedAt,
    this.createdAt,
  });

  factory CareerReview.fromJson(Map<String, dynamic> json) => CareerReview(
        id: json['id'] as String,
        year: json['year'] as int,
        quarter: json['quarter'] as int,
        alignmentScore: json['alignment_score'] as int?,
        technicalProgress: json['technical_progress'] as String?,
        linkedinSummary: json['linkedin_summary'] as String?,
        opportunitiesSummary: json['opportunities_summary'] as String?,
        adjustmentsNeeded: json['adjustments_needed'] as String?,
        completedAt: json['completed_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'year': year,
        'quarter': quarter,
        'alignment_score': alignmentScore,
        'technical_progress': technicalProgress,
        'linkedin_summary': linkedinSummary,
        'opportunities_summary': opportunitiesSummary,
        'adjustments_needed': adjustmentsNeeded,
        'completed_at': completedAt,
      };
}
