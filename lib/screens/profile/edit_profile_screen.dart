// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';

class EditProfileScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> currentData;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.currentData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _passwordController;

  File? _selectedImage;
  bool _isLoading = false;
  bool _changePassword = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentData['name'] ?? '',
    );
    _usernameController = TextEditingController(
      text: widget.currentData['username'] ?? '',
    );
    _bioController = TextEditingController(
      text: widget.currentData['bio'] ?? '',
    );
    _passwordController = TextEditingController();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'الاسم واسم المستخدم مطلوبان');
      return;
    }

    if (username.length < 3) {
      setState(
        () => _errorMessage = 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل',
      );
      return;
    }

    if (_changePassword && password.length < 6) {
      setState(
        () => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if username is taken (if changed)
      if (username != widget.currentData['username']) {
        final existing = await Supabase.instance.client
            .from('users')
            .select()
            .eq('username', username)
            .neq('id', widget.userId)
            .maybeSingle();

        if (existing != null) {
          setState(() => _errorMessage = 'اسم المستخدم موجود مسبقاً');
          return;
        }
      }

      String? avatarUrl = widget.currentData['avatar_url'];

      // Upload new avatar if selected
      if (_selectedImage != null) {
        final fileName =
            'avatar_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}';
        final path = 'avatars/$fileName';
        await Supabase.instance.client.storage
            .from('media')
            .upload(path, _selectedImage!);
        avatarUrl = Supabase.instance.client.storage
            .from('media')
            .getPublicUrl(path);
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'name': name,
        'username': username,
        'bio': bio,
        'avatar_url': avatarUrl,
      };

      // Update password if requested
      if (_changePassword && password.isNotEmpty) {
        updateData['password'] = _hashPassword(password);
      }

      // Update database
      await Supabase.instance.client
          .from('users')
          .update(updateData)
          .eq('id', widget.userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل البروفايل'),
        actions: [
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Avatar
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (widget.currentData['avatar_url'] != null
                                    ? NetworkImage(
                                        widget.currentData['avatar_url'],
                                      )
                                    : null)
                                as ImageProvider?,
                      child:
                          _selectedImage == null &&
                              widget.currentData['avatar_url'] == null
                          ? Icon(
                              Icons.person,
                              size: 50,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickImage,
              child: const Text('تغيير الصورة'),
            ),
            const SizedBox(height: 24),

            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Username
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: const Icon(Icons.alternate_email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 16),

            // Bio
            TextField(
              controller: _bioController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'النبذة التعريفية',
                prefixIcon: const Icon(Icons.info_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
            ),
            const SizedBox(height: 24),

            // Change Password Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline),
                      const SizedBox(width: 8),
                      const Text(
                        'تغيير كلمة المرور',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Switch(
                        value: _changePassword,
                        onChanged: (value) {
                          setState(() => _changePassword = value);
                        },
                      ),
                    ],
                  ),
                  if (_changePassword) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
