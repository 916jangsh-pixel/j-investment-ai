class LongTermReport {
  final int? id;
  final int projectLocalId;
  final String title;
  final DateTime? reportDate;
  final String sourceType;
  final String? storagePath;
  final String? rawText;
  final String? summary;
  final List<String> symbols;
  final List<String> sectors;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LongTermReport({
    this.id,
    required this.projectLocalId,
    required this.title,
    this.reportDate,
    this.sourceType = 'USER_REPORT',
    this.storagePath,
    this.rawText,
    this.summary,
    this.symbols = const [],
    this.sectors = const [],
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory LongTermReport.fromMap(Map<String, dynamic> map) {
    return LongTermReport(
      id: _toInt(map['id']),
      projectLocalId: _toInt(map['project_local_id']) ?? 0,
      title: map['title']?.toString() ?? '',
      reportDate: _toNullableDateTime(map['report_date']),
      sourceType: map['source_type']?.toString() ?? 'USER_REPORT',
      storagePath: map['storage_path']?.toString(),
      rawText: map['raw_text']?.toString(),
      summary: map['summary']?.toString(),
      symbols: _toStringList(map['symbols']),
      sectors: _toStringList(map['sectors']),
      tags: _toStringList(map['tags']),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_local_id': projectLocalId,
      'title': title,
      'report_date': reportDate?.toIso8601String().split('T').first,
      'source_type': sourceType,
      'storage_path': storagePath,
      'raw_text': rawText,
      'summary': summary,
      'symbols': symbols,
      'sectors': sectors,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LongTermReport copyWith({
    int? id,
    int? projectLocalId,
    String? title,
    DateTime? reportDate,
    String? sourceType,
    String? storagePath,
    String? rawText,
    String? summary,
    List<String>? symbols,
    List<String>? sectors,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LongTermReport(
      id: id ?? this.id,
      projectLocalId: projectLocalId ?? this.projectLocalId,
      title: title ?? this.title,
      reportDate: reportDate ?? this.reportDate,
      sourceType: sourceType ?? this.sourceType,
      storagePath: storagePath ?? this.storagePath,
      rawText: rawText ?? this.rawText,
      summary: summary ?? this.summary,
      symbols: symbols ?? this.symbols,
      sectors: sectors ?? this.sectors,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList(growable: false);
  }
}
