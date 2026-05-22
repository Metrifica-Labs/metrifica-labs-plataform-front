class Opportunity {
  final String id;
  final String companyOrEvent;
  final String type;
  final String status;
  final String? roleOrTheme;
  final String? source;
  final int? score;
  final String? dateIdentified;
  final String? nextAction;
  final String? notes;
  final String? outcome;
  final String? closedAt;
  final String? createdAt;

  const Opportunity({
    required this.id,
    required this.companyOrEvent,
    required this.type,
    required this.status,
    this.roleOrTheme,
    this.source,
    this.score,
    this.dateIdentified,
    this.nextAction,
    this.notes,
    this.outcome,
    this.closedAt,
    this.createdAt,
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) => Opportunity(
        id: json['id'] as String,
        companyOrEvent: json['company_or_event'] as String,
        type: json['type'] as String,
        status: json['status'] as String? ?? 'identified',
        roleOrTheme: json['role_or_theme'] as String?,
        source: json['source'] as String?,
        score: json['score'] as int?,
        dateIdentified: json['date_identified'] as String?,
        nextAction: json['next_action'] as String?,
        notes: json['notes'] as String?,
        outcome: json['outcome'] as String?,
        closedAt: json['closed_at'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'company_or_event': companyOrEvent,
        'type': type,
        'status': status,
        'role_or_theme': roleOrTheme,
        'source': source,
        'score': score,
        'date_identified': dateIdentified,
        'next_action': nextAction,
        'notes': notes,
        'outcome': outcome,
      };
}
