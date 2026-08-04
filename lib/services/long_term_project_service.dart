import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/long_term_project.dart';

class LongTermProjectService {
  LongTermProjectService._();

  static final LongTermProjectService instance =
      LongTermProjectService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user.id;
  }

  Future<List<LongTermProject>> getProjects() async {
    final userId = _requireUserId();

    final rows = await _client
        .from('long_term_projects')
        .select()
        .eq('user_id', userId)
        .neq('status', 'ARCHIVED')
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map(
          (row) => LongTermProject.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<LongTermProject> createProject({
    required String name,
    String? description,
  }) async {
    final userId = _requireUserId();
    final now = DateTime.now().toIso8601String();

    final row = await _client
        .from('long_term_projects')
        .insert({
          'user_id': userId,
          'name': name.trim(),
          'description': description,
          'status': 'ACTIVE',
          'created_at': now,
          'updated_at': now,
        })
        .select()
        .single();

    return LongTermProject.fromMap(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> archiveProject(int id) async {
    final userId = _requireUserId();

    await _client
        .from('long_term_projects')
        .update({
          'status': 'ARCHIVED',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', id);
  }
}
