// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../post/post_detail_screen.dart';
import '../profile/profile_screen.dart';

class ExploreScreen extends StatefulWidget {
  final int userId;

  const ExploreScreen({super.key, required this.userId});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  List<PostModel> _posts = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _showUsers = true;
  bool _hasSearched = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _posts = [];
        _users = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final posts = await _postService.searchPosts(query);
      final users = await _userService.searchUsersRaw(query);

      setState(() {
        _posts = posts;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في البحث: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 45,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'بحث عن مستخدمين أو منشورات...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
            onSubmitted: _search,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _search(_searchController.text),
            child: const Text('بحث'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle buttons
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    'مستخدمين',
                    Icons.people,
                    _showUsers,
                    () => setState(() => _showUsers = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleButton(
                    'منشورات',
                    Icons.grid_view,
                    !_showUsers,
                    () => setState(() => _showUsers = false),
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                ? _buildEmptyState()
                : _showUsers
                ? _buildUsersList()
                : _buildPostsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'ابحث عن مستخدمين أو منشورات',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'لا يوجد مستخدمين',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: user['avatar_url'] != null
                  ? NetworkImage(user['avatar_url'])
                  : null,
              child: user['avatar_url'] == null
                  ? Text(
                      (user['name'] ?? user['username'] ?? 'U')
                          .substring(0, 1)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
            ),
            title: Text(
              user['name'] ?? user['username'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '@${user['username'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: user['id'],
                    currentUserId: widget.userId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostsGrid() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد منشورات',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PostDetailScreen(postId: post.id, userId: widget.userId),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: post.mediaUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(post.mediaUrl!, fit: BoxFit.cover),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        post.textContent ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
