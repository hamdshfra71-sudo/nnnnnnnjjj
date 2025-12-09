import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';

class PostService {
  final _supabase = Supabase.instance.client;

  /// إنشاء منشور جديد
  Future<void> createPost({
    required int userId,
    String? textContent,
    String? mediaUrl,
    String? mediaType,
  }) async {
    await _supabase.from('posts').insert({
      'user_id': userId,
      'text_content': textContent,
      'media_url': mediaUrl,
      'media_type': mediaType ?? 'text',
    });
  }

  /// جلب المنشورات للفيد
  Future<List<PostModel>> fetchFeed({int limit = 20, int offset = 0}) async {
    final response = await _supabase
        .from('posts')
        .select('*, users!posts_user_id_fkey(username, name, avatar_url)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) {
      final user = json['users'];
      return PostModel(
        id: json['id'],
        userId: json['user_id'],
        textContent: json['text_content'],
        mediaUrl: json['media_url'],
        mediaType: json['media_type'],
        likesCount: json['likes_count'] ?? 0,
        commentsCount: json['comments_count'] ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        username: user?['name'] ?? user?['username'],
      );
    }).toList();
  }

  /// جلب منشورات مستخدم معين
  Future<List<PostModel>> fetchUserPosts(int userId) async {
    final response = await _supabase
        .from('posts')
        .select('*, users!posts_user_id_fkey(username, name, avatar_url)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final user = json['users'];
      return PostModel(
        id: json['id'],
        userId: json['user_id'],
        textContent: json['text_content'],
        mediaUrl: json['media_url'],
        mediaType: json['media_type'],
        likesCount: json['likes_count'] ?? 0,
        commentsCount: json['comments_count'] ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        username: user?['name'] ?? user?['username'],
      );
    }).toList();
  }

  /// جلب منشور بواسطة ID
  Future<PostModel?> fetchPostById(String postId) async {
    final response = await _supabase
        .from('posts')
        .select('*, users!posts_user_id_fkey(username, name, avatar_url)')
        .eq('id', postId)
        .maybeSingle();

    if (response == null) return null;

    final user = response['users'];
    return PostModel(
      id: response['id'],
      userId: response['user_id'],
      textContent: response['text_content'],
      mediaUrl: response['media_url'],
      mediaType: response['media_type'],
      likesCount: response['likes_count'] ?? 0,
      commentsCount: response['comments_count'] ?? 0,
      createdAt: response['created_at'] != null
          ? DateTime.parse(response['created_at'])
          : null,
      username: user?['name'] ?? user?['username'],
    );
  }

  /// حذف منشور
  Future<void> deletePost(String postId) async {
    await _supabase.from('posts').delete().eq('id', postId);
  }

  /// رفع ملف وسائط (للأجهزة الأصلية)
  Future<String> uploadMedia(File file, String type) async {
    // استخراج اسم الملف بشكل صحيح (يعمل على Windows و Linux/Mac)
    String originalFileName = file.path.split(RegExp(r'[/\\]')).last;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
    final path = '$type/$fileName';

    try {
      await _supabase.storage
          .from('media')
          .upload(
            path,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return _supabase.storage.from('media').getPublicUrl(path);
    } catch (e) {
      throw Exception(
        'فشل رفع الملف: $e - تأكد من إنشاء bucket اسمه "media" في Supabase Storage وتفعيله كـ Public',
      );
    }
  }

  /// رفع ملف وسائط باستخدام bytes (للويب والأجهزة الأصلية)
  Future<String> uploadMediaBytes(
    Uint8List bytes,
    String originalFileName,
    String type,
  ) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$originalFileName';
    final path = '$type/$fileName';

    try {
      await _supabase.storage
          .from('media')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      return _supabase.storage.from('media').getPublicUrl(path);
    } catch (e) {
      throw Exception(
        'فشل رفع الملف: $e - تأكد من إنشاء bucket اسمه "media" في Supabase Storage وتفعيله كـ Public',
      );
    }
  }

  /// البحث عن منشورات
  Future<List<PostModel>> searchPosts(String query) async {
    final response = await _supabase
        .from('posts')
        .select('*, users!posts_user_id_fkey(username, name)')
        .ilike('text_content', '%$query%')
        .order('created_at', ascending: false)
        .limit(30);

    return (response as List).map((json) {
      final user = json['users'];
      return PostModel(
        id: json['id'],
        userId: json['user_id'],
        textContent: json['text_content'],
        mediaUrl: json['media_url'],
        mediaType: json['media_type'],
        likesCount: json['likes_count'] ?? 0,
        commentsCount: json['comments_count'] ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : null,
        username: user?['name'] ?? user?['username'],
      );
    }).toList();
  }
}
