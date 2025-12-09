import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_post_model.dart';

class SavedService {
  final _supabase = Supabase.instance.client;

  /// حفظ منشور
  Future<void> savePost({required int userId, required String postId}) async {
    await _supabase.from('saved_posts').insert({
      'user_id': userId,
      'post_id': postId,
    });
  }

  /// إلغاء الحفظ
  Future<void> unsavePost({required int userId, required String postId}) async {
    await _supabase
        .from('saved_posts')
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }

  /// التحقق من الحفظ
  Future<bool> isSaved({required int userId, required String postId}) async {
    final response = await _supabase
        .from('saved_posts')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    return response != null;
  }

  /// جلب المنشورات المحفوظة
  Future<List<SavedPostModel>> fetchSavedPosts(int userId) async {
    final response = await _supabase
        .from('saved_posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SavedPostModel.fromJson(json))
        .toList();
  }
}
