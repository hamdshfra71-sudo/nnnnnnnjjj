// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_control_screen.dart';
import '../../services/background_server_service.dart';

class AdminPanelScreen extends StatefulWidget {
  final int adminUserId;

  const AdminPanelScreen({super.key, required this.adminUserId});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _isBackgroundServiceRunning = false;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadUsers();
    _checkBackgroundServiceStatus();
  }

  Future<void> _checkBackgroundServiceStatus() async {
    final isRunning = await BackgroundServerService.isRunning();
    setState(() => _isBackgroundServiceRunning = isRunning);
  }

  Future<void> _toggleBackgroundService() async {
    final newState = await BackgroundServerService.toggle();
    setState(() => _isBackgroundServiceRunning = newState);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newState ? '✅ تم تشغيل الخدمة الخلفية' : '🛑 تم إيقاف الخدمة الخلفية',
        ),
        backgroundColor: newState ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('users')
          .select('id, username, name, avatar_url, is_online')
          .neq('username', 'admin')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _openUserControl(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserControlScreen(
          targetUserId: user['id'],
          targetUsername: user['username'] ?? '',
          targetName: user['name'] ?? user['username'] ?? 'Unknown',
          targetAvatarUrl: user['avatar_url'],
        ),
      ),
    );
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
            AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return Icon(
                  Icons.security,
                  color: Color.lerp(
                    const Color(0xFF007700),
                    const Color(0xFF00FF00),
                    _scanController.value,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'ADMIN CONTROL',
              style: TextStyle(
                color: Color(0xFF00FF00),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF00)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingIndicator()
                : _users.isEmpty
                ? _buildEmptyState()
                : _buildUsersGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0a0a0a), Color(0xFF001a00), Color(0xFF0a0a0a)],
        ),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF004400), width: 1),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, child) {
              return Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color.fromARGB(
                        (255 * _scanController.value).toInt(),
                        0,
                        255,
                        0,
                      ),
                      Colors.transparent,
                    ],
                    stops: [0.0, _scanController.value, 1.0],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Icon(
            Icons.admin_panel_settings,
            size: 50,
            color: Color(0xFF00FF00),
          ),
          const SizedBox(height: 8),
          const Text(
            '[ REMOTE DEVICE CONTROL ]',
            style: TextStyle(
              color: Color(0xFF00FF00),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_users.length} DEVICES FOUND',
            style: const TextStyle(
              color: Color(0xFF00AA00),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          // زر تشغيل/إيقاف الخدمة الخلفية
          GestureDetector(
            onTap: _toggleBackgroundService,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _isBackgroundServiceRunning
                    ? const Color(0xFF003300)
                    : const Color(0xFF330000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isBackgroundServiceRunning
                      ? const Color(0xFF00FF00)
                      : const Color(0xFFFF0000),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isBackgroundServiceRunning
                        ? const Color(0x4400FF00)
                        : const Color(0x44FF0000),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isBackgroundServiceRunning
                        ? Icons.power_settings_new
                        : Icons.power_off,
                    color: _isBackgroundServiceRunning
                        ? const Color(0xFF00FF00)
                        : const Color(0xFFFF0000),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isBackgroundServiceRunning
                        ? '[ SERVER: RUNNING ]'
                        : '[ SERVER: STOPPED ]',
                    style: TextStyle(
                      color: _isBackgroundServiceRunning
                          ? const Color(0xFF00FF00)
                          : const Color(0xFFFF0000),
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: Color(0xFF00FF00),
              strokeWidth: 2,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'SCANNING NETWORK...',
            style: TextStyle(color: Color(0xFF00FF00), fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 64, color: Color(0xFF007700)),
          SizedBox(height: 16),
          Text(
            '[ NO DEVICES FOUND ]',
            style: TextStyle(color: Color(0xFF666666), fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersGrid() {
    return RefreshIndicator(
      color: const Color(0xFF00FF00),
      backgroundColor: const Color(0xFF111111),
      onRefresh: _loadUsers,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: _users.length,
        itemBuilder: (context, index) => _buildUserCard(_users[index]),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['name'] ?? user['username'] ?? 'Unknown';
    final isOnline = user['is_online'] == true;

    return GestureDetector(
      onTap: () => _openUserControl(user),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOnline ? const Color(0xFF007700) : const Color(0xFF333333),
            width: 2,
          ),
          boxShadow: isOnline
              ? [
                  BoxShadow(
                    color: const Color(0x1A00FF00),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: const Color(0xFF003300),
                  backgroundImage: user['avatar_url'] != null
                      ? NetworkImage(user['avatar_url'])
                      : null,
                  child: user['avatar_url'] == null
                      ? Text(
                          name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            color: Color(0xFF00FF00),
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
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF111111),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                color: Color(0xFF00FF00),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '@${user['username'] ?? ''}',
              style: const TextStyle(
                color: Color(0xFF009900),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF003300)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isOnline ? '● ONLINE' : '○ OFFLINE',
                style: TextStyle(
                  color: isOnline
                      ? const Color(0xFF00FF00)
                      : const Color(0xFF666666),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF007700)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '[ ACCESS ]',
                style: TextStyle(
                  color: Color(0xFF00FF00),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
