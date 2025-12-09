import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment_model.dart';

class CommentsService {
  final _supabase = Supabase.instance.client;

  /// إضافة تعليق
  Future<void> addComment({
    required String postId,
    required int userId,
    required String text,
  }) async {
    await _supabase.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'text': text,
    });
  }

  /// جلب تعليقات منشور
  Future<List<CommentModel>> fetchComments(String postId) async {
    final response = await _supabase
        .from('comments')
        .select('*, users!comments_user_id_fkey(username, name)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (response as List).map((json) {
      final user = json['users'];
      return CommentModel(
        id: json['id'],
        postId: json['post_id'],
        userId: json['user_id'],
        text: json['text'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        username: user?['name'] ?? user?['username'],
      );
    }).toList();
  }

  /// حذف تعليق
  Future<void> deleteComment(String commentId) async {
    await _supabase.from('comments').delete().eq('id', commentId);
  }
}
