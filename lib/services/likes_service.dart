import 'package:supabase_flutter/supabase_flutter.dart';

class LikesService {
  final _supabase = Supabase.instance.client;

  /// إعجاب بمنشور
  Future<void> likePost({required String postId, required int userId}) async {
    await _supabase.from('likes').insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  /// إلغاء الإعجاب
  Future<void> unlikePost({required String postId, required int userId}) async {
    await _supabase
        .from('likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  /// التحقق من الإعجاب
  Future<bool> isLiked({required String postId, required int userId}) async {
    final response = await _supabase
        .from('likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  /// جلب عدد الإعجابات
  Future<int> getLikesCount(String postId) async {
    final response = await _supabase
        .from('likes')
        .select()
        .eq('post_id', postId);

    return (response as List).length;
  }
}
