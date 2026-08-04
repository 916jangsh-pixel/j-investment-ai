import 'package:supabase_flutter/supabase_flutter.dart';

class LongTermNewsItem {
  final int id;
  final String? symbol;
  final String? sector;
  final String title;
  final String? aiTitleKo;
  final String? sourceName;
  final String? sourceUrl;
  final DateTime? publishedAt;
  final String? summary;
  final String? aiSummaryKo;
  final double? relevanceScore;
  final double? importanceScore;
  final double? impactScore;
  final String? sentiment;
  final List<String> relatedSymbols;
  final List<String> relatedTopics;
  final String? aiRelevanceReason;
  final DateTime? analyzedAt;

  const LongTermNewsItem({
    required this.id,
    this.symbol,
    this.sector,
    required this.title,
    this.aiTitleKo,
    this.sourceName,
    this.sourceUrl,
    this.publishedAt,
    this.summary,
    this.aiSummaryKo,
    this.relevanceScore,
    this.importanceScore,
    this.impactScore,
    this.sentiment,
    this.relatedSymbols = const [],
    this.relatedTopics = const [],
    this.aiRelevanceReason,
    this.analyzedAt,
  });

  String get displayTitle {
    final value = aiTitleKo?.trim();
    return value != null && value.isNotEmpty ? value : title;
  }

  String? get displaySummary {
    final ko = aiSummaryKo?.trim();
    if (ko != null && ko.isNotEmpty) return ko;
    return null;
  }

  String get impactLabel {
    final value = (sentiment ?? '').toUpperCase();
    if (value.contains('POSITIVE') || value.contains('BULLISH')) {
      return '호재';
    }
    if (value.contains('NEGATIVE') || value.contains('BEARISH')) {
      return '악재';
    }
    return '중립';
  }

  bool get isHighImportance => (importanceScore ?? 0) >= 0.6;

  factory LongTermNewsItem.fromMap(Map<String, dynamic> map) {
    return LongTermNewsItem(
      id: _toInt(map['id']) ?? 0,
      symbol: map['symbol']?.toString(),
      sector: map['sector']?.toString(),
      title: map['title']?.toString() ?? '',
      aiTitleKo: map['ai_title_ko']?.toString(),
      sourceName: map['source_name']?.toString(),
      sourceUrl: map['source_url']?.toString(),
      publishedAt: _toDateTime(map['published_at']),
      summary: map['summary']?.toString(),
      aiSummaryKo: map['ai_summary_ko']?.toString(),
      relevanceScore: _toDouble(map['relevance_score']),
      importanceScore: _toDouble(map['importance_score']),
      impactScore: _toDouble(map['impact_score']),
      sentiment: map['sentiment']?.toString(),
      relatedSymbols: _toStringList(map['related_symbols']),
      relatedTopics: _toStringList(map['related_topics']),
      aiRelevanceReason: map['ai_relevance_reason']?.toString(),
      analyzedAt: _toDateTime(map['analyzed_at']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    return value == null ? null : int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return value == null ? null : double.tryParse(value.toString());
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    return value == null ? null : DateTime.tryParse(value.toString());
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
}

class LongTermNewsService {
  LongTermNewsService._();

  static final LongTermNewsService instance = LongTermNewsService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user.id;
  }

  Future<List<LongTermNewsItem>> getNews({
    required int projectLocalId,
    int limit = 100,
  }) async {
    final userId = _requireUserId();

    final rows = await _client
        .from('news_items')
        .select()
        .eq('user_id', userId)
        .eq('project_local_id', projectLocalId)
        .order('importance_score', ascending: false, nullsFirst: false)
        .order('published_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map(
          (row) => LongTermNewsItem.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> refreshNews({
    required int projectLocalId,
  }) async {
    final response = await _client.functions.invoke(
      'long-term-news-refresh',
      body: {
        'project_local_id': projectLocalId,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        '뉴스 갱신 실패 (${response.status}): ${response.data}',
      );
    }

    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }

    return <String, dynamic>{};
  }
}
