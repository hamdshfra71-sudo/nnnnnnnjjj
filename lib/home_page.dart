import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // الحصول على اسم المستخدم من الـ arguments
    final username =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'مستخدم';

    return Scaffold(
      appBar: AppBar(
        title: const Text('الصفحة الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(
              'مرحباً $username!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('تم تسجيل الدخول بنجاح'),
          ],
        ),
      ),
    );
  }
}
