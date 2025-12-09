// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/likes_service.dart';
import '../../services/saved_service.dart';
import '../post/post_detail_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final int userId;
  final String username;

  const HomeScreen({super.key, required this.userId, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PostService _postService = PostService();
  final LikesService _likesService = LikesService();
  final SavedService _savedService = SavedService();

  List<PostModel> _posts = [];
  Map<String, bool> _likedPosts = {};
  Map<String, bool> _savedPosts = {};
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  int _offset = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMorePosts();
      }
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    try {
      final posts = await _postService.fetchFeed(limit: 20, offset: 0);

      // Check liked/saved status for each post
      for (var post in posts) {
        _likedPosts[post.id] = await _likesService.isLiked(
          postId: post.id,
          userId: widget.userId,
        );
        _savedPosts[post.id] = await _savedService.isSaved(
          userId: widget.userId,
          postId: post.id,
        );
      }

      setState(() {
        _posts = posts;
        _offset = posts.length;
        _hasMore = posts.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final posts = await _postService.fetchFeed(limit: 20, offset: _offset);

      for (var post in posts) {
        _likedPosts[post.id] = await _likesService.isLiked(
          postId: post.id,
          userId: widget.userId,
        );
        _savedPosts[post.id] = await _savedService.isSaved(
          userId: widget.userId,
          postId: post.id,
        );
      }

      setState(() {
        _posts.addAll(posts);
        _offset += posts.length;
        _hasMore = posts.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(PostModel post) async {
    final isLiked = _likedPosts[post.id] ?? false;

    setState(() {
      _likedPosts[post.id] = !isLiked;
    });

    try {
      if (isLiked) {
        await _likesService.unlikePost(postId: post.id, userId: widget.userId);
      } else {
        await _likesService.likePost(postId: post.id, userId: widget.userId);
      }
    } catch (e) {
      setState(() {
        _likedPosts[post.id] = isLiked;
      });
    }
  }

  Future<void> _toggleSave(PostModel post) async {
    final isSaved = _savedPosts[post.id] ?? false;

    setState(() {
      _savedPosts[post.id] = !isSaved;
    });

    try {
      if (isSaved) {
        await _savedService.unsavePost(userId: widget.userId, postId: post.id);
      } else {
        await _savedService.savePost(userId: widget.userId, postId: post.id);
      }
    } catch (e) {
      setState(() {
        _savedPosts[post.id] = isSaved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'KSOS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _posts.isEmpty && !_isLoading
            ? _buildEmptyState()
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _posts.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final post = _posts[index];
                  return _PostCard(
                    post: post,
                    isLiked: _likedPosts[post.id] ?? false,
                    isSaved: _savedPosts[post.id] ?? false,
                    onLike: () => _toggleLike(post),
                    onSave: () => _toggleSave(post),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(
                            postId: post.id,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    onProfileTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(
                            userId: post.userId,
                            currentUserId: widget.userId,
                          ),
                        ),
                      );
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
          Icon(Icons.article_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'لا توجد منشورات',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'كن أول من ينشر!',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onProfileTap;

  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.isSaved,
    required this.onLike,
    required this.onSave,
    required this.onTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: GestureDetector(
              onTap: onProfileTap,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: Text(
                        (post.username ?? 'U').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.username ?? 'مستخدم',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _formatTime(post.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // Content
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.textContent != null && post.textContent!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      post.textContent!,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                if (post.mediaUrl != null && post.mediaType == 'image')
                  ClipRRect(
                    child: Image.network(
                      post.mediaUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // Like button with animation
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? Colors.red : Colors.grey.shade600,
                  count: post.likesCount + (isLiked ? 1 : 0),
                  onTap: onLike,
                ),
                const SizedBox(width: 16),
                // Comment button
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  color: Colors.grey.shade600,
                  count: post.commentsCount,
                  onTap: onTap,
                ),
                const SizedBox(width: 16),
                // Share button
                _ActionButton(
                  icon: Icons.share_outlined,
                  color: Colors.grey.shade600,
                  onTap: () {},
                ),
                const Spacer(),
                // Save button
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? colorScheme.primary : Colors.grey.shade600,
                  ),
                  onPressed: onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return '${diff.inHours} ساعة';
    return '${diff.inDays} يوم';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text('$count', style: TextStyle(color: color, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
