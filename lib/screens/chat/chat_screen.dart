// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../profile/profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final int userId;
  final int otherUserId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.userId,
    required this.otherUserId,
    required this.otherUsername,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription? _messagesSubscription;
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSendingImage = false;
  String? _lastSeen;

  @override
  void initState() {
    super.initState();
    _setupRealtimeMessages();
    _chatService.markAsRead(widget.conversationId, widget.userId);
    _loadLastSeen();
    _updateMyLastSeen();
  }

  void _setupRealtimeMessages() {
    // استخدام Real-time للرسائل
    _messagesSubscription = _chatService
        .listenToMessages(widget.conversationId)
        .listen((messages) {
          if (mounted) {
            setState(() {
              _messages = messages;
              _isLoading = false;
            });
            _scrollToBottom();
            // تحديث حالة القراءة
            _chatService.markAsRead(widget.conversationId, widget.userId);
          }
        });
  }

  Future<void> _loadLastSeen() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('last_seen')
          .eq('id', widget.otherUserId)
          .maybeSingle();

      if (response != null && response['last_seen'] != null && mounted) {
        setState(() {
          _lastSeen = _formatLastSeen(DateTime.parse(response['last_seen']));
        });
      }
    } catch (e) {
      // إذا فشل، نستخدم القيمة الافتراضية
    }
  }

  Future<void> _updateMyLastSeen() async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('id', widget.userId);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  String _formatLastSeen(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 2) return 'متصل الآن';
    if (diff.inMinutes < 60) return 'آخر ظهور منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'آخر ظهور منذ ${diff.inHours} ساعة';
    return 'آخر ظهور منذ ${diff.inDays} يوم';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text, String? mediaUrl}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && mediaUrl == null) return;

    _messageController.clear();

    try {
      await _chatService.sendMessage(
        conversationId: widget.conversationId,
        senderId: widget.userId,
        receiverId: widget.otherUserId,
        text: mediaUrl != null ? null : messageText,
        mediaUrl: mediaUrl,
      );
      // لا حاجة لـ _loadMessages - Real-time سيحدث تلقائياً
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    Navigator.pop(context); // إغلاق Bottom Sheet

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image == null) return;

      setState(() => _isSendingImage = true);

      // قراءة الصورة كـ bytes
      final bytes = await image.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final path = 'chat/$fileName';

      // رفع الصورة
      await Supabase.instance.client.storage
          .from('media')
          .uploadBinary(path, bytes);

      final imageUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl(path);

      // إرسال الرسالة مع الصورة
      await _sendMessage(mediaUrl: imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إرسال الصورة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'إرسال مرفق',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'المعرض',
                  color: Colors.purple,
                  onTap: () => _pickAndSendImage(ImageSource.gallery),
                ),
                if (!kIsWeb)
                  _AttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'الكاميرا',
                    color: Colors.blue,
                    onTap: () => _pickAndSendImage(ImageSource.camera),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        title: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  userId: widget.otherUserId,
                  currentUserId: widget.userId,
                ),
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Text(
                  widget.otherUsername.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUsername,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _lastSeen ?? 'جاري التحميل...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(color: colorScheme.surfaceContainerLowest),
        child: Column(
          children: [
            // Messages
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'ابدأ المحادثة الآن!',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.senderId == widget.userId;
                        final showDate =
                            index == 0 ||
                            _shouldShowDate(
                              _messages[index - 1].createdAt,
                              message.createdAt,
                            );

                        return Column(
                          children: [
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _formatDate(message.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            _buildMessageBubble(message, isMe, colorScheme),
                          ],
                        );
                      },
                    ),
            ),

            // Sending image indicator
            if (_isSendingImage)
              Container(
                padding: const EdgeInsets.all(8),
                color: colorScheme.primaryContainer,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('جاري إرسال الصورة...'),
                  ],
                ),
              ),

            // Message input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Attachment button
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.add, color: colorScheme.primary),
                        onPressed: _showAttachmentOptions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Text field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالة...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Send button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () => _sendMessage(),
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

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMe,
    ColorScheme colorScheme,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 50 : 0,
          right: isMe ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                )
              : null,
          color: isMe ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.mediaUrl!,
                    width: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 150,
                        color: Colors.grey.shade200,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      width: 200,
                      height: 100,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            if (message.text != null && message.text!.isNotEmpty)
              Text(
                message.text!,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade500,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead
                        ? Colors.lightBlueAccent
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowDate(DateTime? prev, DateTime? current) {
    if (prev == null || current == null) return true;
    return prev.day != current.day ||
        prev.month != current.month ||
        prev.year != current.year;
  }

  String _formatDate(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    if (time.day == now.day &&
        time.month == now.month &&
        time.year == now.year) {
      return 'اليوم';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (time.day == yesterday.day &&
        time.month == yesterday.month &&
        time.year == yesterday.year) {
      return 'أمس';
    }
    return '${time.day}/${time.month}/${time.year}';
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
