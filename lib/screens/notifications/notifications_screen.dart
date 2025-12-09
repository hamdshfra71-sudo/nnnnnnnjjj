// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  final int userId;

  const NotificationsScreen({super.key, required this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final notifications = await _notificationService.fetchNotifications(
        widget.userId,
      );
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsSeen() async {
    await _notificationService.markAllAsSeen(widget.userId);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton.icon(
              onPressed: _markAllAsSeen,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('قراءة الكل'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _NotificationTile(
                    notification: notification,
                    onTap: () async {
                      await _notificationService.markAsSeen(notification.id);
                      _loadNotifications();
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد إشعارات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر إشعاراتك هنا',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconData = _getIcon(notification.type);
    final iconColor = _getIconColor(notification.type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: notification.isSeen
            ? colorScheme.surface
            : colorScheme.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        title: Text(
          _getNotificationText(notification.type),
          style: TextStyle(
            fontWeight: notification.isSeen
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _formatTime(notification.createdAt),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ),
        trailing: notification.isSeen
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      case 'message':
        return Icons.mail;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String? type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'message':
        return Colors.green;
      case 'system':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  String _getNotificationText(String? type) {
    switch (type) {
      case 'like':
        return 'أعجب شخص بمنشورك ❤️';
      case 'comment':
        return 'علّق شخص على منشورك 💬';
      case 'message':
        return 'لديك رسالة جديدة 📩';
      case 'system':
        return 'إشعار من النظام 📢';
      default:
        return 'إشعار جديد';
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${time.day}/${time.month}/${time.year}';
  }
}
