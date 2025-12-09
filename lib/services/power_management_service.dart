import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة الطاقة - تطلب من المستخدم إعفاء التطبيق من تحسين البطارية
class PowerManagementService {
  static const String _askedForOptimizationKey = 'asked_battery_optimization';

  /// طلب إعفاء التطبيق من تحسين البطارية (يُظهر للمستخدم مرة واحدة فقط)
  static Future<void> requestBatteryOptimizationExemption() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedForOptimizationKey) ?? false;

    if (alreadyAsked) {
      debugPrint('🔋 PowerManagement: Already asked for battery optimization');
      return;
    }

    try {
      // التحقق من الحالة الحالية
      final isIgnoring = await Permission.ignoreBatteryOptimizations.isGranted;

      if (isIgnoring) {
        debugPrint('✅ PowerManagement: Battery optimization already disabled');
        await prefs.setBool(_askedForOptimizationKey, true);
        return;
      }

      // طلب الإعفاء من المستخدم
      debugPrint(
        '🔋 PowerManagement: Requesting battery optimization exemption...',
      );
      await Permission.ignoreBatteryOptimizations.request();

      // تسجيل أننا طلبنا
      await prefs.setBool(_askedForOptimizationKey, true);
      debugPrint('✅ PowerManagement: Battery optimization dialog shown');
    } catch (e) {
      debugPrint('❌ PowerManagement: Error requesting exemption: $e');
    }
  }

  /// التحقق من حالة تحسين البطارية
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final result = await Permission.ignoreBatteryOptimizations.isGranted;
      return result;
    } catch (e) {
      debugPrint('❌ PowerManagement: Error checking status: $e');
      return false;
    }
  }

  /// إعادة تعيين العلامة (للتجربة)
  static Future<void> resetAskedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_askedForOptimizationKey);
    debugPrint('🔁 PowerManagement: Reset asked flag');
  }
}
