class LongTermProject {
  final int? id;
  final String name;
  final String? description;
  final String status;
  final String? investmentTheme;
  final String? investmentGoal;
  final String? investmentHorizon;
  final String? reportSummary;
  final String? investmentThesis;
  final String? keyCriteria;
  final String? riskFactors;
  final String? finalSummary;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LongTermProject({
    this.id,
    required this.name,
    this.description,
    this.status = 'ACTIVE',
    this.investmentTheme,
    this.investmentGoal,
    this.investmentHorizon,
    this.reportSummary,
    this.investmentThesis,
    this.keyCriteria,
    this.riskFactors,
    this.finalSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LongTermProject.fromMap(Map<String, dynamic> map) {
    return LongTermProject(
      id: _toInt(map['id']),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString(),
      status: map['status']?.toString() ?? 'ACTIVE',
      investmentTheme: map['investment_theme']?.toString(),
      investmentGoal: map['investment_goal']?.toString(),
      investmentHorizon: map['investment_horizon']?.toString(),
      reportSummary: map['report_summary']?.toString(),
      investmentThesis: map['investment_thesis']?.toString(),
      keyCriteria: map['key_criteria']?.toString(),
      riskFactors: map['risk_factors']?.toString(),
      finalSummary: map['final_summary']?.toString(),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'description': description,
    'status': status,
    'investment_theme': investmentTheme,
    'investment_goal': investmentGoal,
    'investment_horizon': investmentHorizon,
    'report_summary': reportSummary,
    'investment_thesis': investmentThesis,
    'key_criteria': keyCriteria,
    'risk_factors': riskFactors,
    'final_summary': finalSummary,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  LongTermProject copyWith({
    int? id,
    String? name,
    String? description,
    String? status,
    String? investmentTheme,
    String? investmentGoal,
    String? investmentHorizon,
    String? reportSummary,
    String? investmentThesis,
    String? keyCriteria,
    String? riskFactors,
    String? finalSummary,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => LongTermProject(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    status: status ?? this.status,
    investmentTheme: investmentTheme ?? this.investmentTheme,
    investmentGoal: investmentGoal ?? this.investmentGoal,
    investmentHorizon: investmentHorizon ?? this.investmentHorizon,
    reportSummary: reportSummary ?? this.reportSummary,
    investmentThesis: investmentThesis ?? this.investmentThesis,
    keyCriteria: keyCriteria ?? this.keyCriteria,
    riskFactors: riskFactors ?? this.riskFactors,
    finalSummary: finalSummary ?? this.finalSummary,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }
}
