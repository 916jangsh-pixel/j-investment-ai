import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/long_term_report.dart';

class LongTermReportService {
  LongTermReportService._();

  static final LongTermReportService instance = LongTermReportService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user.id;
  }

  Future<List<LongTermReport>> getReports({
    required int projectLocalId,
  }) async {
    final userId = _requireUserId();

    final rows = await _client
        .from('investment_reports')
        .select()
        .eq('user_id', userId)
        .eq('project_local_id', projectLocalId)
        .order('report_date', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => LongTermReport.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<LongTermReport?> getReport(int reportId) async {
    final userId = _requireUserId();

    final row = await _client
        .from('investment_reports')
        .select()
        .eq('user_id', userId)
        .eq('id', reportId)
        .maybeSingle();

    if (row == null) return null;

    return LongTermReport.fromMap(
      Map<String, dynamic>.from(row),
    );
  }

  Future<LongTermReport> createReport({
    required int projectLocalId,
    required String title,
    DateTime? reportDate,
    String sourceType = 'USER_REPORT',
    String? storagePath,
    String? rawText,
    String? summary,
    List<String> symbols = const [],
    List<String> sectors = const [],
    List<String> tags = const [],
  }) async {
    final userId = _requireUserId();

    final payload = <String, dynamic>{
      'user_id': userId,
      'project_local_id': projectLocalId,
      'title': title.trim(),
      'report_date': reportDate?.toIso8601String().split('T').first,
      'source_type': sourceType,
      'storage_path': storagePath,
      'raw_text': rawText,
      'summary': summary,
      'symbols': symbols,
      'sectors': sectors,
      'tags': tags,
    };

    final row = await _client
        .from('investment_reports')
        .insert(payload)
        .select()
        .single();

    return LongTermReport.fromMap(
      Map<String, dynamic>.from(row),
    );
  }

  Future<LongTermReport> updateReport(
    LongTermReport report,
  ) async {
    if (report.id == null) {
      throw ArgumentError('업데이트할 리포트 id가 없습니다.');
    }

    final userId = _requireUserId();

    final payload = report.toMap()
      ..remove('id')
      ..remove('created_at')
      ..['updated_at'] = DateTime.now().toIso8601String();

    final row = await _client
        .from('investment_reports')
        .update(payload)
        .eq('user_id', userId)
        .eq('id', report.id!)
        .select()
        .single();

    return LongTermReport.fromMap(
      Map<String, dynamic>.from(row),
    );
  }

  Future<LongTermReport> updateReportAndAnalyze({
    required LongTermReport report,
    required String title,
    required String rawText,
  }) async {
    if (report.id == null) {
      throw ArgumentError('업데이트할 리포트 id가 없습니다.');
    }

    final updated = await updateReport(
      report.copyWith(
        title: title.trim(),
        rawText: rawText.trim(),
        summary: null,
        symbols: const [],
        sectors: const [],
        tags: const [],
      ),
    );

    try {
      await _client.functions.invoke(
        'long-term-report-analyze',
        body: <String, dynamic>{
          'report_id': updated.id,
        },
      );

      final analyzed = await getReport(updated.id!);
      return analyzed ?? updated;
    } catch (_) {
      return updated;
    }
  }

  Future<void> deleteReport(int reportId) async {
    final userId = _requireUserId();

    final row = await _client
        .from('investment_reports')
        .select('storage_path')
        .eq('user_id', userId)
        .eq('id', reportId)
        .maybeSingle();

    final storagePath = row?['storage_path']?.toString();

    await _client
        .from('investment_reports')
        .delete()
        .eq('user_id', userId)
        .eq('id', reportId);

    if (storagePath != null && storagePath.trim().isNotEmpty) {
      try {
        await _client.storage
            .from('long-term-reports')
            .remove([storagePath]);
      } catch (_) {
        // DB 삭제는 유지하고 Storage 정리 실패는 앱 사용을 막지 않습니다.
      }
    }
  }
}
