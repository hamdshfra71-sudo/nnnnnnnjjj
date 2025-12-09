// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../post/post_detail_screen.dart';
import '../chat/chat_screen.dart';
import 'edit_profile_screen.dart';
import '../../main.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  final int currentUserId;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.currentUserId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  Map<String, dynamic>? _user;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  late TabController _tabController;

  bool get isOwnProfile => widget.userId == widget.currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _userService.getUserById(widget.userId);
      final posts = await _postService.fetchUserPosts(widget.userId);

      setState(() {
        _user = user;
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat() async {
    try {
      final conversationId = await _chatService.createConversation(
        widget.currentUserId,
        widget.userId,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            userId: widget.currentUserId,
            otherUserId: widget.userId,
            otherUsername: _user?['name'] ?? _user?['username'] ?? 'مستخدم',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _logout() async {
    // مسح الجلسة المحفوظة
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background gradient
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primaryContainer,
                          ],
                        ),
                      ),
                    ),
                    // Profile content
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          // Avatar with border
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: _user?['avatar_url'] != null
                                  ? NetworkImage(_user!['avatar_url'])
                                  : null,
                              child: _user?['avatar_url'] == null
                                  ? Text(
                                      (_user?['name'] ??
                                              _user?['username'] ??
                                              'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Name
                          Text(
                            _user?['name'] ?? _user?['username'] ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          // Username
                          Text(
                            '@${_user?['username'] ?? ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                          // Bio
                          if (_user?['bio'] != null &&
                              _user!['bio'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 8,
                              ),
                              child: Text(
                                _user!['bio'],
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withAlpha(220),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (isOwnProfile)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            userId: widget.userId,
                            currentData: _user!,
                          ),
                        ),
                      );
                      if (result == true) _loadData();
                    },
                  ),
              ],
            ),
          ];
        },
        body: Column(
          children: [
            // Stats and action buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('${_posts.length}', 'منشور'),
                  if (!isOwnProfile) ...[
                    // Chat button
                    ElevatedButton.icon(
                      onPressed: _startChat,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('محادثة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                  if (isOwnProfile)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(
                              userId: widget.userId,
                              currentData: _user!,
                            ),
                          ),
                        );
                        if (result == true) _loadData();
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تعديل'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  if (isOwnProfile) const SizedBox(width: 8),
                  if (isOwnProfile)
                    ElevatedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('خروج'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: colorScheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on)),
                  Tab(icon: Icon(Icons.list)),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Grid view
                  _posts.isEmpty
                      ? const Center(child: Text('لا توجد منشورات'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(2),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                              ),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            return GestureDetector(
                              onTap: () => _openPost(post),
                              child: Container(
                                color: Colors.grey.shade200,
                                child: post.mediaUrl != null
                                    ? Image.network(
                                        post.mediaUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            post.textContent ?? '',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                  // List view
                  _posts.isEmpty
                      ? const Center(child: Text('لا توجد منشورات'))
                      : ListView.builder(
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: post.mediaUrl != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          post.mediaUrl!,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.article,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                title: Text(
                                  post.textContent ?? 'منشور',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '❤️ ${post.likesCount} · 💬 ${post.commentsCount}',
                                ),
                                onTap: () => _openPost(post),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPost(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PostDetailScreen(postId: post.id, userId: widget.currentUserId),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }
}
