class LinkedinMetrics {
  final String id;
  final String month;
  final int? followers;
  final int? postsPublished;
  final int? avgImpressions;
  final int? newRelevantContacts;
  final int? recruiterOpportunities;
  final String? topPost;
  final String? bottomPost;
  final String? whatWorked;
  final String? whatDidnt;
  final String? nextMonthAdjustment;
  final String? createdAt;

  const LinkedinMetrics({
    required this.id,
    required this.month,
    this.followers,
    this.postsPublished,
    this.avgImpressions,
    this.newRelevantContacts,
    this.recruiterOpportunities,
    this.topPost,
    this.bottomPost,
    this.whatWorked,
    this.whatDidnt,
    this.nextMonthAdjustment,
    this.createdAt,
  });

  factory LinkedinMetrics.fromJson(Map<String, dynamic> json) => LinkedinMetrics(
        id: json['id'] as String,
        month: json['month'] as String,
        followers: json['followers'] as int?,
        postsPublished: json['posts_published'] as int?,
        avgImpressions: json['avg_impressions'] as int?,
        newRelevantContacts: json['new_relevant_contacts'] as int?,
        recruiterOpportunities: json['recruiter_opportunities'] as int?,
        topPost: json['top_post'] as String?,
        bottomPost: json['bottom_post'] as String?,
        whatWorked: json['what_worked'] as String?,
        whatDidnt: json['what_didnt'] as String?,
        nextMonthAdjustment: json['next_month_adjustment'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'month': month,
        'followers': followers,
        'posts_published': postsPublished,
        'avg_impressions': avgImpressions,
        'new_relevant_contacts': newRelevantContacts,
        'recruiter_opportunities': recruiterOpportunities,
        'top_post': topPost,
        'bottom_post': bottomPost,
        'what_worked': whatWorked,
        'what_didnt': whatDidnt,
        'next_month_adjustment': nextMonthAdjustment,
      };
}
