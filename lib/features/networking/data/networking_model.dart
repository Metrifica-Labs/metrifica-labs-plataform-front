class NetworkingContact {
  final String id;
  final String name;
  final String? role;
  final String? company;
  final String? profileType;
  final String? linkedinUrl;
  final String? howMet;
  final String? firstContactDate;
  final String? lastContactDate;
  final String? relationshipStatus;
  final bool? generatedOpportunity;
  final String? notes;
  final String? createdAt;

  const NetworkingContact({
    required this.id,
    required this.name,
    this.role,
    this.company,
    this.profileType,
    this.linkedinUrl,
    this.howMet,
    this.firstContactDate,
    this.lastContactDate,
    this.relationshipStatus,
    this.generatedOpportunity,
    this.notes,
    this.createdAt,
  });

  factory NetworkingContact.fromJson(Map<String, dynamic> json) =>
      NetworkingContact(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String?,
        company: json['company'] as String?,
        profileType: json['profile_type'] as String?,
        linkedinUrl: json['linkedin_url'] as String?,
        howMet: json['how_met'] as String?,
        firstContactDate: json['first_contact_date'] as String?,
        lastContactDate: json['last_contact_date'] as String?,
        relationshipStatus: json['relationship_status'] as String?,
        generatedOpportunity: json['generated_opportunity'] as bool?,
        notes: json['notes'] as String?,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'company': company,
        'profile_type': profileType,
        'linkedin_url': linkedinUrl,
        'how_met': howMet,
        'first_contact_date': firstContactDate,
        'last_contact_date': lastContactDate,
        'relationship_status': relationshipStatus,
        'generated_opportunity': generatedOpportunity,
        'notes': notes,
      };
}
