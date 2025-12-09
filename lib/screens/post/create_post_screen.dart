// ignore_for_file: use_build_context_synchronously
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/post_service.dart';

class CreatePostScreen extends StatefulWidget {
  final int userId;

  const CreatePostScreen({super.key, required this.userId});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PostService _postService = PostService();
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedMedia;
  Uint8List? _mediaBytes; // للعرض على الويب
  String _mediaType = 'text';
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedMedia = image;
        _mediaBytes = bytes;
        _mediaType = 'image';
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (video != null) {
      final bytes = await video.readAsBytes();
      setState(() {
        _selectedMedia = video;
        _mediaBytes = bytes;
        _mediaType = 'video';
      });
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      // الكاميرا غير مدعومة على الويب بشكل مباشر، نستخدم المعرض
      await _pickImage();
      return;
    }

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      setState(() {
        _selectedMedia = photo;
        _mediaBytes = bytes;
        _mediaType = 'image';
      });
    }
  }

  Future<void> _createPost() async {
    if (_textController.text.isEmpty && _selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('اكتب شيئاً أو أضف صورة'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? mediaUrl;

      // رفع الوسائط إذا وجدت
      if (_selectedMedia != null && _mediaBytes != null) {
        try {
          mediaUrl = await _postService.uploadMediaBytes(
            _mediaBytes!,
            _selectedMedia!.name,
            _mediaType,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'خطأ في رفع الصورة: $e\n\nتأكد من إنشاء bucket اسمه media في Supabase Storage',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // إنشاء المنشور
      await _postService.createPost(
        userId: widget.userId,
        textContent: _textController.text.isNotEmpty
            ? _textController.text
            : null,
        mediaUrl: mediaUrl,
        mediaType: mediaUrl != null ? _mediaType : 'text',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نشر المنشور بنجاح! ✨'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      String errorMessage = 'خطأ: $e';
      if (e.toString().contains('foreign key') ||
          e.toString().contains('user_id')) {
        errorMessage = 'خطأ: تأكد من تشغيل ملف SQL في Supabase';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMediaPreview() {
    if (_mediaBytes == null) return const SizedBox.shrink();

    if (_mediaType == 'image') {
      return Image.memory(
        _mediaBytes!,
        width: double.infinity,
        height: 300,
        fit: BoxFit.cover,
      );
    } else {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam, color: Colors.white, size: 50),
              SizedBox(height: 8),
              Text('فيديو محدد', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'منشور جديد',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('نشر'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Text input
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _textController,
                maxLines: 8,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'ما الذي يدور في ذهنك؟ ✨',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  counterStyle: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            ),

            // Selected media preview
            if (_selectedMedia != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildMediaPreview(),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedMedia = null;
                            _mediaBytes = null;
                            _mediaType = 'text';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Media options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MediaButton(
                    icon: Icons.photo_library,
                    label: 'صورة',
                    color: Colors.green,
                    onTap: _pickImage,
                  ),
                  _MediaButton(
                    icon: Icons.camera_alt,
                    label: 'كاميرا',
                    color: Colors.blue,
                    onTap: _takePhoto,
                  ),
                  _MediaButton(
                    icon: Icons.videocam,
                    label: 'فيديو',
                    color: Colors.red,
                    onTap: _pickVideo,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Tips
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'نصيحة: المنشورات مع الصور تحصل على تفاعل أكثر! 📸',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
