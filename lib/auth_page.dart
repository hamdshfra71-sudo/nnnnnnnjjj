import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // تشفير كلمة المرور باستخدام SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // تسجيل حساب جديد
  Future<void> _signUp() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // التحقق من عدم وجود المستخدم
      final existing = await Supabase.instance.client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        setState(() => _errorMessage = 'اسم المستخدم موجود مسبقاً');
        return;
      }

      // تشفير كلمة المرور قبل الحفظ
      final hashedPassword = _hashPassword(password);

      // إنشاء المستخدم
      await Supabase.instance.client.from('users').insert({
        'username': username,
        'password': hashedPassword,
      });

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/home', arguments: username);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // تسجيل الدخول
  Future<void> _signIn() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'أدخل اسم المستخدم وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // تشفير كلمة المرور للمقارنة
      final hashedPassword = _hashPassword(password);

      // البحث عن المستخدم
      final user = await Supabase.instance.client
          .from('users')
          .select()
          .eq('username', username)
          .eq('password', hashedPassword)
          .maybeSingle();

      if (user == null) {
        setState(() => _errorMessage = 'اسم المستخدم أو كلمة المرور خطأ');
        return;
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacementNamed('/home', arguments: username);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signIn,
                      child: const Text('تسجيل الدخول'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _signUp,
                      child: const Text('إنشاء حساب جديد'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
