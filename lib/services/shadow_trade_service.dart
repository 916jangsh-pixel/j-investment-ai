import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shadow_trade.dart';

class ShadowTradeService {
  ShadowTradeService._();
  static final ShadowTradeService instance = ShadowTradeService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _userId() {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Supabase 로그인 사용자가 없습니다.');
    return user.id;
  }

  Future<ShadowTrade> create({
    required String symbol,
    required String instrument,
    required String timeframe,
    required String direction,
    required double entryPrice,
    required double stopPrice,
    required double targetPrice,
    double leverage = 1,
    double virtualMargin = 100,
    double feeRate = 0.0005,
    int? sourceAnalysisId,
    int? sourceTradeLocalId,
    double? jScore,
    double? aiConfidence,
    String? patternType,
    String? marketRegime,
    String? entryReason,
    Map<String, dynamic>? entrySnapshot,
  }) async {
    final dir = direction.trim().toUpperCase();
    if (dir != 'LONG' && dir != 'SHORT') {
      throw ArgumentError('direction은 LONG 또는 SHORT여야 합니다.');
    }

    final row = await _client.from('shadow_trades').insert({
      'user_id': _userId(),
      'source_analysis_id': sourceAnalysisId,
      'source_trade_local_id': sourceTradeLocalId,
      'symbol': symbol.toUpperCase(),
      'instrument': instrument.toUpperCase(),
      'timeframe': timeframe,
      'direction': dir,
      'entry_price': entryPrice,
      'stop_price': stopPrice,
      'target_price': targetPrice,
      'leverage': leverage,
      'virtual_margin': virtualMargin,
      'fee_rate': feeRate,
      'j_score': jScore,
      'ai_confidence': aiConfidence,
      'pattern_type': patternType,
      'market_regime': marketRegime,
      'entry_reason': entryReason,
      'entry_snapshot': entrySnapshot ?? <String, dynamic>{},
      'current_price': entryPrice,
      'status': 'OPEN',
    }).select().single();

    return ShadowTrade.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<ShadowTrade>> getAll({int limit = 100}) async {
    final rows = await _client
        .from('shadow_trades')
        .select()
        .eq('user_id', _userId())
        .order('opened_at', ascending: false)
        .limit(limit.clamp(1, 500));

    return (rows as List)
        .map((e) => ShadowTrade.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  Future<List<ShadowTrade>> getOpen() async {
    final rows = await _client
        .from('shadow_trades')
        .select()
        .eq('user_id', _userId())
        .eq('status', 'OPEN')
        .order('opened_at', ascending: false);

    return (rows as List)
        .map((e) => ShadowTrade.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }

  String? resolve(ShadowTrade trade, double price) {
    if (trade.direction == 'LONG') {
      if (price <= trade.stopPrice) return 'LOSS';
      if (price >= trade.targetPrice) return 'WIN';
    } else {
      if (price >= trade.stopPrice) return 'LOSS';
      if (price <= trade.targetPrice) return 'WIN';
    }
    return null;
  }

  Future<void> updateExcursion(ShadowTrade trade, double price) async {
    if (trade.id == null || trade.entryPrice <= 0) return;

    final rawMove = ((price - trade.entryPrice) / trade.entryPrice) * 100;
    final signedMove = trade.direction == 'SHORT' ? -rawMove : rawMove;

    final mfe = signedMove > trade.mfePercent ? signedMove : trade.mfePercent;
    final mae = signedMove < trade.maePercent ? signedMove : trade.maePercent;

    await _client.from('shadow_trades').update({
      'current_price': price,
      'mfe_percent': mfe,
      'mae_percent': mae,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', trade.id!);
  }

  Future<void> close({
    required ShadowTrade trade,
    required double exitPrice,
    required String status,
    String? successReason,
    String? failureReason,
    String? lesson,
    Map<String, dynamic>? exitSnapshot,
  }) async {
    if (trade.id == null) throw StateError('shadow trade id가 없습니다.');

    final directionMultiplier = trade.direction == 'SHORT' ? -1.0 : 1.0;
    final priceReturn =
        ((exitPrice - trade.entryPrice) / trade.entryPrice) * directionMultiplier;

    final notional = trade.virtualMargin * trade.leverage;
    final grossPnl = notional * priceReturn;
    final fee = notional * trade.feeRate * 2;
    final netPnl = grossPnl - fee;
    final returnPercent =
        trade.virtualMargin > 0 ? (netPnl / trade.virtualMargin) * 100 : 0.0;

    final risk = (trade.entryPrice - trade.stopPrice).abs();
    final pnlMove = (exitPrice - trade.entryPrice).abs();
    final rMultiple =
        risk > 0 ? (pnlMove / risk) * (netPnl >= 0 ? 1 : -1) : 0.0;

    await _client.from('shadow_trades').update({
      'status': status.toUpperCase(),
      'current_price': exitPrice,
      'exit_price': exitPrice,
      'gross_pnl': grossPnl,
      'fee': fee,
      'net_pnl': netPnl,
      'return_percent': returnPercent,
      'r_multiple': rMultiple,
      'success_reason': successReason,
      'failure_reason': failureReason,
      'lesson': lesson,
      'exit_snapshot': exitSnapshot ?? <String, dynamic>{},
      'closed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', trade.id!);
  }
}
