import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/long_term_chat_message.dart';

class LongTermAiService {
  LongTermAiService._();

  static final LongTermAiService instance = LongTermAiService._();

  SupabaseClient get _client => Supabase.instance.client;

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase 로그인 사용자가 없습니다.');
    }
    return user.id;
  }

  Future<int> createConversation({
    required int projectLocalId,
    String title = '새 대화',
  }) async {
    final userId = _requireUserId();

    final row = await _client
        .from('long_term_conversations')
        .insert({
          'user_id': userId,
          'project_local_id': projectLocalId,
          'title': title,
          'status': 'OPEN',
        })
        .select('id')
        .single();

    final id = row['id'];
    if (id is int) return id;

    final parsed = int.tryParse(id.toString());
    if (parsed == null) {
      throw StateError('대화 ID를 읽지 못했습니다.');
    }
    return parsed;
  }

  Future<List<Map<String, dynamic>>> getConversations({
    required int projectLocalId,
  }) async {
    final userId = _requireUserId();

    final rows = await _client
        .from('long_term_conversations')
        .select('id, title, status, created_at, updated_at')
        .eq('user_id', userId)
        .eq('project_local_id', projectLocalId)
        .order('updated_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Future<List<LongTermChatMessage>> getMessages({
    required int conversationId,
  }) async {
    final userId = _requireUserId();

    final rows = await _client
        .from('long_term_messages')
        .select()
        .eq('user_id', userId)
        .eq('conversation_id', conversationId)
        // 메시지는 DB에 들어간 순서(id)대로 고정합니다.
        // USER 저장 후 ASSISTANT가 저장되므로 질문 → 답변 순서가 항상 유지됩니다.
        .order('id', ascending: true);

    return (rows as List<dynamic>)
        .map(
          (row) => LongTermChatMessage.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> saveUserMessage({
    required int projectLocalId,
    required int conversationId,
    required String content,
  }) async {
    final userId = _requireUserId();

    await _client.from('long_term_messages').insert({
      'user_id': userId,
      'project_local_id': projectLocalId,
      'conversation_id': conversationId,
      'role': 'USER',
      'content': content.trim(),
    });

    await _touchConversation(conversationId);
  }

  Future<String> askAiAfterUserSaved({
    required int projectLocalId,
    required int conversationId,
    required String message,
  }) async {
    final response = await _client.functions.invoke(
      'long-term-ai-chat',
      body: {
        'project_local_id': projectLocalId,
        'conversation_id': conversationId,
        'message': message.trim(),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      throw StateError(
        '장기 AI 호출 실패 (${response.status}): ${response.data}',
      );
    }

    await _touchConversation(conversationId);

    final data = response.data;
    if (data is Map && data['answer'] != null) {
      return data['answer'].toString();
    }

    return 'AI 응답을 읽지 못했습니다.';
  }

  // 기존 호출부 호환용. 새 채팅 화면에서는 saveUserMessage 후
  // askAiAfterUserSaved를 사용해 질문을 즉시 화면에 표시합니다.
  Future<String> askAi({
    required int projectLocalId,
    required int conversationId,
    required String message,
  }) async {
    await saveUserMessage(
      projectLocalId: projectLocalId,
      conversationId: conversationId,
      content: message,
    );

    return askAiAfterUserSaved(
      projectLocalId: projectLocalId,
      conversationId: conversationId,
      message: message,
    );
  }

  Future<void> updateConversationTitle({
    required int conversationId,
    required String title,
  }) async {
    final userId = _requireUserId();
    final clean = title.trim();
    if (clean.isEmpty) return;

    await _client
        .from('long_term_conversations')
        .update({
          'title': clean,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', conversationId);
  }

  Future<void> deleteConversation({
    required int conversationId,
  }) async {
    final userId = _requireUserId();

    await _client
        .from('long_term_messages')
        .delete()
        .eq('user_id', userId)
        .eq('conversation_id', conversationId);

    await _client
        .from('long_term_conversations')
        .delete()
        .eq('user_id', userId)
        .eq('id', conversationId);
  }

  Future<void> finalizeConversation({
    required int conversationId,
  }) async {
    final userId = _requireUserId();

    await _client
        .from('long_term_conversations')
        .update({
          'status': 'FINALIZED',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', conversationId);
  }

  Future<void> _touchConversation(int conversationId) async {
    final userId = _requireUserId();

    await _client
        .from('long_term_conversations')
        .update({
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('id', conversationId);
  }
}
