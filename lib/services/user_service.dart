import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  /// الحصول على مستخدم بواسطة ID (يرجع البيانات الخام)
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    final response = await _supabase
        .from('users')
        .select('id, username, name, bio, avatar_url, created_at')
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  /// الحصول على profile (للتوافق مع الكود القديم)
  Future<ProfileModel?> getProfile(int userId) async {
    final response = await _supabase
        .from('users')
        .select('id, username, name, bio, avatar_url, created_at')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel(
      id: response['id'],
      username: response['username'],
      name: response['name'],
      bio: response['bio'],
      avatarUrl: response['avatar_url'],
    );
  }

  /// تحديث المستخدم
  Future<void> updateUser(int userId, Map<String, dynamic> data) async {
    await _supabase.from('users').update(data).eq('id', userId);
  }

  /// البحث عن مستخدمين (يرجع ProfileModel)
  Future<List<ProfileModel>> searchUsers(String query) async {
    final response = await _supabase
        .from('users')
        .select('id, username, name, bio, avatar_url')
        .or('username.ilike.%$query%,name.ilike.%$query%')
        .limit(20);

    return (response as List)
        .map(
          (json) => ProfileModel(
            id: json['id'],
            username: json['username'],
            name: json['name'],
            bio: json['bio'],
            avatarUrl: json['avatar_url'],
          ),
        )
        .toList();
  }

  /// البحث عن مستخدمين (يرجع البيانات الخام)
  Future<List<Map<String, dynamic>>> searchUsersRaw(String query) async {
    final response = await _supabase
        .from('users')
        .select('id, username, name, bio, avatar_url')
        .or('username.ilike.%$query%,name.ilike.%$query%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// جلب جميع المستخدمين
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _supabase
        .from('users')
        .select('id, username, name, bio, avatar_url')
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  }
}
