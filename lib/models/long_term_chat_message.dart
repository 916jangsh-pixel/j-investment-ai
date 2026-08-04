class LongTermChatMessage {
  final int? id;
  final int projectLocalId;
  final int conversationId;
  final String role;
  final String content;
  final List<int> referencedReportIds;
  final List<int> referencedNewsIds;
  final DateTime createdAt;

  const LongTermChatMessage({
    this.id,
    required this.projectLocalId,
    required this.conversationId,
    required this.role,
    required this.content,
    this.referencedReportIds = const [],
    this.referencedNewsIds = const [],
    required this.createdAt,
  });

  bool get isUser => role == 'USER';
  bool get isAssistant => role == 'ASSISTANT';

  factory LongTermChatMessage.fromMap(Map<String, dynamic> map) {
    return LongTermChatMessage(
      id: _toInt(map['id']),
      projectLocalId: _toInt(map['project_local_id']) ?? 0,
      conversationId: _toInt(map['conversation_id']) ?? 0,
      role: map['role']?.toString() ?? 'ASSISTANT',
      content: map['content']?.toString() ?? '',
      referencedReportIds: _toIntList(map['referenced_report_ids']),
      referencedNewsIds: _toIntList(map['referenced_news_ids']),
      createdAt: _toDateTime(map['created_at']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static List<int> _toIntList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(_toInt)
        .whereType<int>()
        .toList(growable: false);
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    final parsed = value == null ? null : DateTime.tryParse(value.toString());
    return parsed ?? DateTime.now();
  }
}
