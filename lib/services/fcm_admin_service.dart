import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// خدمة FCM Admin - إرسال إشعارات FCM باستخدام HTTP v1 API
///
/// تستخدم Firebase Admin SDK Service Account للمصادقة
/// وترسل الإشعارات عبر HTTP v1 API الجديد
class FCMAdminService {
  static ServiceAccountCredentials? _credentials;
  static AutoRefreshingAuthClient? _client;
  static const String _projectId = 'nnnnnn-7793e';
  static const String _serviceAccountPath =
      'assets/nnnnnn-7793e-firebase-adminsdk-fbsvc-a58e16ec79.json';

  /// تهيئة الخدمة وتحميل المفاتيح من الأصول
  static Future<void> initialize() async {
    if (_credentials != null) return;

    try {
      // تحميل ملف Service Account من الأصول
      final jsonString = await rootBundle.loadString(_serviceAccountPath);
      final jsonMap = json.decode(jsonString) as Map<String, dynamic>;

      _credentials = ServiceAccountCredentials.fromJson(jsonMap);
      debugPrint('FCM Admin: Service account loaded successfully');
    } catch (e) {
      debugPrint('FCM Admin: Error loading service account: $e');
      rethrow;
    }
  }

  /// الحصول على Access Token للمصادقة
  static Future<String> _getAccessToken() async {
    if (_credentials == null) {
      await initialize();
    }

    try {
      // إنشاء عميل مصادق عبر OAuth2
      if (_client == null || _client!.credentials.accessToken.hasExpired) {
        _client = await clientViaServiceAccount(_credentials!, [
          'https://www.googleapis.com/auth/firebase.messaging',
        ]);
        debugPrint('FCM Admin: New access token obtained');
      }

      return _client!.credentials.accessToken.data;
    } catch (e) {
      debugPrint('FCM Admin: Error getting access token: $e');
      rethrow;
    }
  }

  /// إرسال إشعار FCM إلى جهاز محدد
  ///
  /// [fcmToken] - رمز FCM للجهاز المستهدف
  /// [commandType] - نوع الأمر (flash_on, flash_off, camera_front, إلخ)
  /// [commandId] - معرف الأمر في قاعدة البيانات
  static Future<bool> sendNotification({
    required String fcmToken,
    required String commandType,
    required String commandId,
  }) async {
    try {
      final accessToken = await _getAccessToken();

      final url = Uri.parse(
        'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send',
      );

      final message = {
        'message': {
          'token': fcmToken,
          'data': {
            'command_type': commandType,
            'command_id': commandId,
            'timestamp': DateTime.now().toIso8601String(),
          },
          'android': {
            'priority': 'high',
            'ttl': '86400s', // صلاحية 24 ساعة
            'direct_boot_ok': true, // إيقاظ الجهاز حتى لو كان مقفل
          },
          // لا نضع notification حتى يتم معالجة الرسالة في الخلفية
        },
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode(message),
      );

      debugPrint('FCM Admin: Response status: ${response.statusCode}');
      debugPrint('FCM Admin: Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ FCM Admin: Message sent successfully to device');
        return true;
      } else if (response.statusCode == 404) {
        debugPrint(
          '❌ FCM Admin: Token not found - user may have uninstalled app',
        );
        return false;
      } else if (response.statusCode == 401) {
        // Token expired, reset and retry
        _client = null;
        debugPrint('⚠️ FCM Admin: Token expired, retrying...');
        return await sendNotification(
          fcmToken: fcmToken,
          commandType: commandType,
          commandId: commandId,
        );
      } else {
        debugPrint('❌ FCM Admin: Failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ FCM Admin: Error sending notification: $e');
      return false;
    }
  }

  /// إغلاق العميل وتنظيف الموارد
  static void dispose() {
    _client?.close();
    _client = null;
  }
}
