import 'package:supabase_flutter/supabase_flutter.dart';

import 'okx_market_service.dart';
import 'technical_indicator_service.dart';

class ShortTermAiAnalysis {
  final int? analysisId;
  final int? memoryId;
  final int tradeLocalId;
  final int projectLocalId;
  final String directionAdvice;
  final double confidence;
  final String summary;
  final List<String> reasons;
  final List<String> risks;
  final List<String> confirmationConditions;
  final List<String> invalidationConditions;
  final Map<String, dynamic> suggestedPrices;
  final List<int> similarTradeIds;

  const ShortTermAiAnalysis({
    required this.analysisId,
    required this.memoryId,
    required this.tradeLocalId,
    required this.projectLocalId,
    required this.directionAdvice,
    required this.confidence,
    required this.summary,
    required this.reasons,
    required this.risks,
    required this.confirmationConditions,
    required this.invalidationConditions,
    required this.suggestedPrices,
    required this.similarTradeIds,
  });

  factory ShortTermAiAnalysis.fromJson(Map<String, dynamic> json) {
    final result = _asMap(json['result']);

    return ShortTermAiAnalysis(
      analysisId: _asIntOrNull(json['analysis_id']),
      memoryId: _asIntOrNull(json['memory_id']),
      tradeLocalId: _asInt(json['trade_local_id']),
      projectLocalId: _asInt(json['project_local_id']),
      directionAdvice:
          (result['direction_advice'] ?? 'WAIT').toString().toUpperCase(),
      confidence: _asDouble(result['confidence']),
      summary: (result['summary'] ?? '').toString(),
      reasons: _asStringList(result['reasons']),
      risks: _asStringList(result['risks']),
      confirmationConditions:
          _asStringList(result['confirmation_conditions']),
      invalidationConditions:
          _asStringList(result['invalidation_conditions']),
      suggestedPrices: _asMap(result['suggested_prices']),
      similarTradeIds: _asIntList(result['similar_trade_ids']),
    );
  }

  int get confidencePercent => (confidence * 100).round();

  String get directionLabel {
    switch (directionAdvice) {
      case 'LONG':
        return '롱 우세';
      case 'SHORT':
        return '숏 우세';
      case 'AVOID':
        return '진입 회피';
      case 'WAIT':
      default:
        return '관망';
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<int> _asIntList(dynamic value) {
    if (value is! List) return const <int>[];
    return value
        .map((item) {
          if (item is int) return item;
          if (item is num) return item.toInt();
          return int.tryParse(item?.toString() ?? '');
        })
        .whereType<int>()
        .toList(growable: false);
  }
}

class ShortTermAiService {
  ShortTermAiService._();

  static final ShortTermAiService instance = ShortTermAiService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<ShortTermAiAnalysis> analyzePreEntry({
    required int projectLocalId,
    required String symbol,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }

    if (projectLocalId <= 0) {
      throw ArgumentError.value(
        projectLocalId,
        'projectLocalId',
        '0보다 큰 값이어야 합니다.',
      );
    }

    final cleanSymbol = symbol.trim().toUpperCase();
    if (cleanSymbol.isEmpty) {
      throw ArgumentError.value(symbol, 'symbol', '종목을 입력해주세요.');
    }

    final okx = OkxMarketService.instance;
    final ticker = await okx.getTicker(symbol: cleanSymbol);
    final candles = await okx.getMultiTimeframeCandles(
      symbol: cleanSymbol,
      limit: 100,
    );

    final snapshots =
        TechnicalIndicatorService.instance.analyzeMultiTimeframe(candles);

    final marketContext = <String, dynamic>{
      'source': 'OKX',
      'symbol': cleanSymbol,
      'instrument': okx.toSwapInstId(cleanSymbol),
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'ticker': <String, dynamic>{
        'last': ticker.last,
        'bid': ticker.bid,
        'ask': ticker.ask,
        'high_24h': ticker.high24h,
        'low_24h': ticker.low24h,
        'change_24h_percent': ticker.change24hPercent,
      },
      'timeframes': <String, dynamic>{
        for (final entry in snapshots.entries)
          entry.key: entry.value.toJson(),
      },
    };

    final response = await _client.functions.invoke(
      'short-term-pre-entry-analyze',
      body: <String, dynamic>{
        'project_local_id': projectLocalId,
        'symbol': cleanSymbol,
        'market_context': marketContext,
      },
    );

    final data = response.data;

    if (data is! Map) {
      throw StateError('진입 전 AI 분석 응답 형식이 올바르지 않습니다.');
    }

    final json = data.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (json['success'] != true) {
      final error = json['error']?.toString().trim();
      final stage = json['stage']?.toString().trim();

      throw StateError(
        [
          if (stage != null && stage.isNotEmpty) '[$stage]',
          if (error != null && error.isNotEmpty) error,
          if (error == null || error.isEmpty) '진입 전 AI 분석에 실패했습니다.',
        ].join(' '),
      );
    }

    return ShortTermAiAnalysis.fromJson(json);
  }

  Future<ShortTermAiAnalysis> analyzeTrade({
    required int tradeLocalId,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }

    if (tradeLocalId <= 0) {
      throw ArgumentError.value(
        tradeLocalId,
        'tradeLocalId',
        '0보다 큰 값이어야 합니다.',
      );
    }

    Map<String, dynamic>? marketContext;
    String? marketContextError;

    try {
      // 현재 매매 종목을 Supabase에서 확인한 뒤 그 종목의 OKX 데이터를 가져온다.
      // BTC에 하드코딩하지 않아 ETHUSDT / SOLUSDT 등에도 그대로 확장 가능하다.
      final tradeRow = await _client
          .from('trades')
          .select('symbol')
          .eq('user_id', user.id)
          .eq('local_id', tradeLocalId)
          .maybeSingle();

      final symbol = tradeRow?['symbol']?.toString().trim();

      if (symbol == null || symbol.isEmpty) {
        throw StateError('현재 매매의 symbol을 찾을 수 없습니다.');
      }

      final okx = OkxMarketService.instance;
      final instId = okx.toSwapInstId(symbol);

      final candles = await okx.getMultiTimeframeCandles(
        symbol: symbol,
        limit: 100,
      );

      final snapshots =
          TechnicalIndicatorService.instance.analyzeMultiTimeframe(candles);

      marketContext = <String, dynamic>{
        'source': 'OKX',
        'symbol': symbol.toUpperCase(),
        'instrument': instId,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
        'timeframes': <String, dynamic>{
          for (final entry in snapshots.entries)
            entry.key: entry.value.toJson(),
        },
      };
    } catch (error) {
      marketContextError = error.toString();
    }

    final response = await _client.functions.invoke(
      'short-term-trade-analyze',
      body: <String, dynamic>{
        'trade_local_id': tradeLocalId,
        if (marketContext != null) 'market_context': marketContext,
        if (marketContextError != null)
          'market_context_error': marketContextError,
      },
    );

    final data = response.data;

    if (data is! Map) {
      throw StateError('AI 분석 응답 형식이 올바르지 않습니다.');
    }

    final json = data.map<String, dynamic>(
      (key, value) => MapEntry(key.toString(), value),
    );

    if (json['success'] != true) {
      final error = json['error']?.toString().trim();
      final stage = json['stage']?.toString().trim();

      throw StateError(
        [
          if (stage != null && stage.isNotEmpty) '[$stage]',
          if (error != null && error.isNotEmpty) error,
          if ((error == null || error.isEmpty)) 'AI 분석에 실패했습니다.',
        ].join(' '),
      );
    }

    return ShortTermAiAnalysis.fromJson(json);
  }

  Future<List<Map<String, dynamic>>> getTradeAnalyses({
    required int tradeLocalId,
    int limit = 20,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }

    final safeLimit = limit.clamp(1, 100);

    final rows = await _client
        .from('ai_analyses')
        .select()
        .eq('user_id', user.id)
        .eq('trade_local_id', tradeLocalId)
        .order('created_at', ascending: false)
        .limit(safeLimit);

    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> getLatestTradeAnalysis({
    required int tradeLocalId,
  }) async {
    final rows = await getTradeAnalyses(
      tradeLocalId: tradeLocalId,
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }
}
