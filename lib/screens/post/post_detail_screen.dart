// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../services/post_service.dart';
import '../../services/comments_service.dart';
import '../../services/likes_service.dart';
import '../../services/saved_service.dart';
import '../profile/profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final int userId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.userId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final PostService _postService = PostService();
  final CommentsService _commentsService = CommentsService();
  final LikesService _likesService = LikesService();
  final SavedService _savedService = SavedService();
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  PostModel? _post;
  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final post = await _postService.fetchPostById(widget.postId);
      final comments = await _commentsService.fetchComments(widget.postId);
      final isLiked = await _likesService.isLiked(
        postId: widget.postId,
        userId: widget.userId,
      );
      final isSaved = await _savedService.isSaved(
        userId: widget.userId,
        postId: widget.postId,
      );

      setState(() {
        _post = post;
        _comments = comments;
        _isLiked = isLiked;
        _isSaved = isSaved;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    setState(() => _isLiked = !_isLiked);

    try {
      if (_isLiked) {
        await _likesService.likePost(
          postId: widget.postId,
          userId: widget.userId,
        );
      } else {
        await _likesService.unlikePost(
          postId: widget.postId,
          userId: widget.userId,
        );
      }
    } catch (e) {
      setState(() => _isLiked = !_isLiked);
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _isSaved = !_isSaved);

    try {
      if (_isSaved) {
        await _savedService.savePost(
          userId: widget.userId,
          postId: widget.postId,
        );
      } else {
        await _savedService.unsavePost(
          userId: widget.userId,
          postId: widget.postId,
        );
      }
    } catch (e) {
      setState(() => _isSaved = !_isSaved);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSendingComment = true);

    try {
      await _commentsService.addComment(
        postId: widget.postId,
        userId: widget.userId,
        text: _commentController.text.trim(),
      );
      _commentController.clear();
      _focusNode.unfocus();
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('المنشور غير موجود')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنشور'),
        actions: [IconButton(icon: const Icon(Icons.share), onPressed: () {})],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post content
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: _post!.userId,
                                    currentUserId: widget.userId,
                                  ),
                                ),
                              );
                            },
                            child: Row(
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
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Colors.white,
                                    child: Text(
                                      (_post!.username ?? 'U')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _post!.username ?? 'مستخدم',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatTime(_post!.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Text content
                        if (_post!.textContent != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              _post!.textContent!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),

                        // Media
                        if (_post!.mediaUrl != null &&
                            _post!.mediaType == 'image')
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(20),
                            ),
                            child: Image.network(
                              _post!.mediaUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),

                        // Actions
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _ActionButton(
                                icon: _isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isLiked
                                    ? Colors.red
                                    : Colors.grey.shade600,
                                label:
                                    '${_post!.likesCount + (_isLiked ? 1 : 0)}',
                                onTap: _toggleLike,
                              ),
                              const SizedBox(width: 20),
                              _ActionButton(
                                icon: Icons.chat_bubble_outline,
                                color: Colors.grey.shade600,
                                label: '${_comments.length}',
                                onTap: () => _focusNode.requestFocus(),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  _isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: _isSaved
                                      ? colorScheme.primary
                                      : Colors.grey.shade600,
                                ),
                                onPressed: _toggleSave,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Comments section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'التعليقات',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_comments.length}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Comments list
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'لا توجد تعليقات',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Text(
                              'كن أول من يعلق!',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return _CommentTile(
                          comment: comment,
                          currentUserId: widget.userId,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Comment input
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
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: 'أضف تعليقاً...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSendingComment
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isSendingComment ? null : _addComment,
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

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
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
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final int currentUserId;

  const _CommentTile({required this.comment, required this.currentUserId});

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileScreen(userId: comment.userId, currentUserId: currentUserId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openProfile(context),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                (comment.username ?? 'U').substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openProfile(context),
                      child: Text(
                        comment.username ?? 'مستخدم',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.text),
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
    if (diff.inMinutes < 60) return '${diff.inMinutes}د';
    if (diff.inHours < 24) return '${diff.inHours}س';
    return '${diff.inDays}ي';
  }
}
