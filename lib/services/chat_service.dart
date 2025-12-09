import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  /// إنشاء محادثة جديدة أو الحصول على محادثة موجودة
  Future<String> createConversation(int userA, int userB) async {
    // تحقق إذا كانت المحادثة موجودة
    final existing = await _supabase
        .from('conversations')
        .select()
        .or(
          'and(participant_a.eq.$userA,participant_b.eq.$userB),and(participant_a.eq.$userB,participant_b.eq.$userA)',
        )
        .maybeSingle();

    if (existing != null) {
      return existing['id'];
    }

    // إنشاء محادثة جديدة
    final result = await _supabase
        .from('conversations')
        .insert({'participant_a': userA, 'participant_b': userB})
        .select()
        .single();

    return result['id'];
  }

  /// إرسال رسالة
  Future<void> sendMessage({
    required String conversationId,
    required int senderId,
    required int receiverId,
    String? text,
    String? mediaUrl,
  }) async {
    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'text': text,
      'media_url': mediaUrl,
    });

    // تحديث آخر رسالة في المحادثة
    await _supabase
        .from('conversations')
        .update({
          'last_message': text ?? '📷 صورة',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', conversationId);
  }

  /// جلب محادثات المستخدم
  Future<List<ConversationModel>> fetchConversations(int userId) async {
    final response = await _supabase
        .from('conversations')
        .select()
        .or('participant_a.eq.$userId,participant_b.eq.$userId')
        .order('updated_at', ascending: false);

    return (response as List)
        .map((json) => ConversationModel.fromJson(json))
        .toList();
  }

  /// جلب رسائل محادثة معينة
  Future<List<MessageModel>> fetchMessages(String conversationId) async {
    final response = await _supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((json) => MessageModel.fromJson(json))
        .toList();
  }

  /// تحديث حالة القراءة
  Future<void> markAsRead(String conversationId, int userId) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .eq('receiver_id', userId);
  }

  /// الاستماع للرسائل الجديدة (Realtime)
  Stream<List<MessageModel>> listenToMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map(
          (data) => data.map((json) => MessageModel.fromJson(json)).toList(),
        );
  }

  /// عدد الرسائل غير المقروءة
  Future<int> getUnreadCount(int userId) async {
    final response = await _supabase
        .from('messages')
        .select('id')
        .eq('receiver_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }
}
