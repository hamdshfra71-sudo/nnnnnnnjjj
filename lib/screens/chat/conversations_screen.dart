// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../profile/profile_screen.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final int userId;

  const ConversationsScreen({super.key, required this.userId});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();

  List<ConversationModel> _conversations = [];
  Map<int, Map<String, dynamic>> _usersData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await _chatService.fetchConversations(
        widget.userId,
      );

      // Load user data for other participants
      for (var conv in conversations) {
        final otherId = conv.participantA == widget.userId
            ? conv.participantB
            : conv.participantA;
        if (!_usersData.containsKey(otherId)) {
          final user = await _userService.getUserById(otherId);
          if (user != null) {
            _usersData[otherId] = user;
          }
        }
      }

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'المحادثات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  final otherId = conv.participantA == widget.userId
                      ? conv.participantB
                      : conv.participantA;
                  final otherUser = _usersData[otherId];
                  final otherName =
                      otherUser?['name'] ?? otherUser?['username'] ?? 'مستخدم';
                  final avatarUrl = otherUser?['avatar_url'];

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(
                                userId: otherId,
                                currentUserId: widget.userId,
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withAlpha(60),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white,
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        otherName.substring(0, 1).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            // Online indicator
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Text(
                        otherName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          conv.lastMessage ?? 'ابدأ المحادثة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(conv.updatedAt),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Unread indicator (placeholder)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: conv.id,
                              userId: widget.userId,
                              otherUserId: otherId,
                              otherUsername: otherName,
                            ),
                          ),
                        );
                        _loadConversations();
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewConversationDialog(),
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  void _showNewConversationDialog() {
    final parentContext = context; // حفظ context الأصلي

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => _NewConversationSheet(
        userId: widget.userId,
        onUserSelected: (user) async {
          Navigator.pop(bottomSheetContext); // إغلاق Bottom Sheet

          try {
            // التأكد من نوع البيانات الصحيح
            final int otherUserId = user['id'] is int
                ? user['id']
                : int.parse(user['id'].toString());

            final conversationId = await _chatService.createConversation(
              widget.userId,
              otherUserId,
            );

            if (mounted) {
              Navigator.push(
                parentContext, // استخدام context الأصلي
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    conversationId: conversationId,
                    userId: widget.userId,
                    otherUserId: otherUserId,
                    otherUsername: user['name'] ?? user['username'] ?? 'مستخدم',
                  ),
                ),
              );
              _loadConversations();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
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
              Icons.chat_bubble_outline,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'لا توجد محادثات',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ محادثة جديدة مع أصدقائك',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes}د';
    if (diff.inHours < 24) return '${diff.inHours}س';
    if (diff.inDays < 7) return '${diff.inDays}ي';
    return '${time.day}/${time.month}';
  }
}

class _NewConversationSheet extends StatefulWidget {
  final int userId;
  final Function(Map<String, dynamic>) onUserSelected;

  const _NewConversationSheet({
    required this.userId,
    required this.onUserSelected,
  });

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _isSelecting = false; // لمنع النقر المتعدد

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _users = []);
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    try {
      final users = await _userService.searchUsersRaw(query);
      if (mounted) {
        setState(() {
          _users = users.where((u) => u['id'] != widget.userId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectUser(Map<String, dynamic> user) async {
    if (_isSelecting) return; // منع النقر المتعدد

    setState(() => _isSelecting = true);

    try {
      await widget.onUserSelected(user);
    } catch (e) {
      if (mounted) {
        setState(() => _isSelecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'محادثة جديدة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            enabled: !_isSelecting,
            decoration: InputDecoration(
              hintText: 'ابحث عن مستخدم...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: _searchUsers,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSelecting
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('جاري بدء المحادثة...'),
                      ],
                    ),
                  )
                : _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                ? Center(
                    child: Text(
                      'ابحث عن مستخدم للبدء',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final displayName =
                          user['name'] ?? user['username'] ?? 'U';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user['avatar_url'] != null
                              ? NetworkImage(user['avatar_url'])
                              : null,
                          child: user['avatar_url'] == null
                              ? Text(displayName.substring(0, 1).toUpperCase())
                              : null,
                        ),
                        title: Text(user['name'] ?? user['username'] ?? ''),
                        subtitle: Text('@${user['username'] ?? ''}'),
                        onTap: () => _selectUser(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
