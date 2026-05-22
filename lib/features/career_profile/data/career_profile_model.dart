class CareerProfile {
  final String id;
  final String name;
  final String role;
  final String company;
  final String? companyTier;
  final String? specialization;
  final List<String>? technologies;
  final List<String>? certifications;
  final int? yearsInTech;
  final int? yearsInSales;
  final String? currentGoals;
  final String? finalObjective;
  final String? updatedAt;

  const CareerProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.company,
    this.companyTier,
    this.specialization,
    this.technologies,
    this.certifications,
    this.yearsInTech,
    this.yearsInSales,
    this.currentGoals,
    this.finalObjective,
    this.updatedAt,
  });

  factory CareerProfile.fromJson(Map<String, dynamic> json) => CareerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        company: json['company'] as String,
        companyTier: json['company_tier'] as String?,
        specialization: json['specialization'] as String?,
        technologies: (json['technologies'] as List?)?.cast<String>(),
        certifications: (json['certifications'] as List?)?.cast<String>(),
        yearsInTech: json['years_in_tech'] as int?,
        yearsInSales: json['years_in_sales'] as int?,
        currentGoals: json['current_goals'] as String?,
        finalObjective: json['final_objective'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'company': company,
        'company_tier': companyTier,
        'specialization': specialization,
        'technologies': technologies,
        'certifications': certifications,
        'years_in_tech': yearsInTech,
        'years_in_sales': yearsInSales,
        'current_goals': currentGoals,
        'final_objective': finalObjective,
      };

  CareerProfile copyWith({
    String? name,
    String? role,
    String? company,
    String? companyTier,
    String? specialization,
    List<String>? technologies,
    List<String>? certifications,
    int? yearsInTech,
    int? yearsInSales,
    String? currentGoals,
    String? finalObjective,
  }) =>
      CareerProfile(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        company: company ?? this.company,
        companyTier: companyTier ?? this.companyTier,
        specialization: specialization ?? this.specialization,
        technologies: technologies ?? this.technologies,
        certifications: certifications ?? this.certifications,
        yearsInTech: yearsInTech ?? this.yearsInTech,
        yearsInSales: yearsInSales ?? this.yearsInSales,
        currentGoals: currentGoals ?? this.currentGoals,
        finalObjective: finalObjective ?? this.finalObjective,
        updatedAt: updatedAt,
      );
}
