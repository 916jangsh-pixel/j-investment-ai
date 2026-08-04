import 'package:supabase_flutter/supabase_flutter.dart';

class LongTermWatchlistService {
  LongTermWatchlistService._();

  static final LongTermWatchlistService instance =
      LongTermWatchlistService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _userId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user.id;
  }

  Future<Set<String>> getSymbols({
    required int projectLocalId,
  }) async {
    final uid = _userId();

    final rows = await _client
        .from('long_term_watchlist')
        .select('symbol')
        .eq('user_id', uid)
        .eq('project_local_id', projectLocalId);

    return (rows as List)
        .map((e) => (e as Map)['symbol']?.toString().toUpperCase() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> getItems({
    required int projectLocalId,
  }) async {
    final uid = _userId();

    final rows = await _client
        .from('long_term_watchlist')
        .select()
        .eq('user_id', uid)
        .eq('project_local_id', projectLocalId)
        .order('updated_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> getHistory({
    required int projectLocalId,
    required String symbol,
    int limit = 30,
  }) async {
    final uid = _userId();

    final rows = await _client
        .from('long_term_watchlist_history')
        .select()
        .eq('user_id', uid)
        .eq('project_local_id', projectLocalId)
        .eq('symbol', symbol.toUpperCase())
        .order('analyzed_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> refreshTracking({
    required int projectLocalId,
  }) async {
    _userId();

    final response = await _client.functions.invoke(
      'long-term-watchlist-refresh',
      body: {
        'project_local_id': projectLocalId,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        '관심종목 재분석 실패 (${response.status}): ${response.data}',
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('관심종목 재분석 응답 형식이 올바르지 않습니다.');
    }

    final result = Map<String, dynamic>.from(data);
    if (result['success'] == false) {
      throw StateError(
        result['error']?.toString() ?? '관심종목 재분석에 실패했습니다.',
      );
    }

    return result;
  }

  Future<void> add({
    required int projectLocalId,
    required Map<String, dynamic> candidate,
  }) async {
    final uid = _userId();
    final symbol =
        candidate['symbol']?.toString().trim().toUpperCase() ?? '';

    if (symbol.isEmpty) {
      throw StateError('종목 심볼이 없습니다.');
    }

    await _client.from('long_term_watchlist').upsert({
      'user_id': uid,
      'project_local_id': projectLocalId,
      'symbol': symbol,
      'company_name': candidate['company_name']?.toString(),
      'score': candidate['score'],
      'verdict': candidate['verdict']?.toString(),
      'thesis': candidate['thesis']?.toString(),
      'supporting_evidence': candidate['supporting_evidence'] is List
          ? candidate['supporting_evidence']
          : <dynamic>[],
      'risks':
          candidate['risks'] is List ? candidate['risks'] : <dynamic>[],
      'watch_conditions': candidate['watch_conditions'] is List
          ? candidate['watch_conditions']
          : <dynamic>[],
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,project_local_id,symbol');
  }

  Future<void> remove({
    required int projectLocalId,
    required String symbol,
  }) async {
    final uid = _userId();

    await _client
        .from('long_term_watchlist')
        .delete()
        .eq('user_id', uid)
        .eq('project_local_id', projectLocalId)
        .eq('symbol', symbol.toUpperCase());
  }
}
