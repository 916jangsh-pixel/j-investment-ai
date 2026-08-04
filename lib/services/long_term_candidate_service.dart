import 'package:supabase_flutter/supabase_flutter.dart';

class LongTermCandidateService {
  LongTermCandidateService._();

  static final LongTermCandidateService instance =
      LongTermCandidateService._();

  SupabaseClient get _client => Supabase.instance.client;

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user;
  }

  Future<Map<String, dynamic>?> getLatestCandidates({
    required int projectLocalId,
  }) async {
    _requireUser();

    final response = await _client.functions.invoke(
      'long-term-candidates',
      body: {
        'action': 'latest',
        'project_local_id': projectLocalId,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        '저장된 후보 불러오기 실패 (${response.status}): ${response.data}',
      );
    }

    final data = response.data;
    if (data is! Map) return null;

    final result = Map<String, dynamic>.from(data);

    if (result['success'] == false) {
      throw StateError(
        result['error']?.toString() ?? '저장된 후보를 불러오지 못했습니다.',
      );
    }

    if (result['found'] != true) return null;
    return result;
  }

  Future<Map<String, dynamic>> generateCandidates({
    required int projectLocalId,
  }) async {
    _requireUser();

    final response = await _client.functions.invoke(
      'long-term-candidates',
      body: {
        'action': 'generate',
        'project_local_id': projectLocalId,
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        '최종 후보 생성 실패 (${response.status}): ${response.data}',
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw StateError('최종 후보 응답 형식이 올바르지 않습니다.');
    }

    final result = Map<String, dynamic>.from(data);

    if (result['success'] == false) {
      throw StateError(
        result['error']?.toString() ?? '최종 후보 생성에 실패했습니다.',
      );
    }

    return result;
  }
}
