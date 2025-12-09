import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  /// إنشاء إشعار
  Future<void> createNotification({
    required int userId,
    required String type,
    String? relatedId,
  }) async {
    await _supabase.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'related_id': relatedId,
    });
  }

  /// جلب إشعارات المستخدم
  Future<List<NotificationModel>> fetchNotifications(int userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((json) => NotificationModel.fromJson(json))
        .toList();
  }

  /// تعليم الإشعارات كمقروءة
  Future<void> markAsSeen(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_seen': true})
        .eq('id', notificationId);
  }

  /// تعليم كل الإشعارات كمقروءة
  Future<void> markAllAsSeen(int userId) async {
    await _supabase
        .from('notifications')
        .update({'is_seen': true})
        .eq('user_id', userId);
  }

  /// عدد الإشعارات غير المقروءة
  Future<int> getUnseenCount(int userId) async {
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('is_seen', false);

    return (response as List).length;
  }
}
