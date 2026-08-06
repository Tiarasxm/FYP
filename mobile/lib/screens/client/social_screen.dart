import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/social_post.dart';
import '../../models/client/user_profile.dart';
import 'create_post_page.dart';
import 'post_card.dart';
import 'public_profile_page.dart';
import 'view_post_page.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<SocialPost> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserName;
  String? _currentUserAvatarUrl;
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _loadCurrentUserAvatar();
  }

  Future<void> _loadCurrentUserAvatar() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      final metadata = user.userMetadata;
      if (!mounted) return;
      setState(() {
        _currentUserName = profile?['full_name']?.toString();
        _currentUserAvatarUrl = profile?['avatar_url']?.toString() ??
            metadata?['avatar_url']?.toString() ??
            metadata?['picture']?.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserName = user.email;
        _currentUserAvatarUrl = user.userMetadata?['avatar_url']?.toString() ??
            user.userMetadata?['picture']?.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      List<String>? allowedUserIds;
      if (selectedTab == 1) {
        final currentUserId = _supabase.auth.currentUser?.id;
        if (currentUserId == null) throw Exception('You must be signed in.');

        final followRows = await _supabase
            .from('follows')
            .select('following_id')
            .eq('follower_id', currentUserId);
        allowedUserIds = (followRows as List<dynamic>)
            .map((row) => (row as Map<String, dynamic>)['following_id']?.toString())
            .whereType<String>()
            .toList();

        if (allowedUserIds.isEmpty) {
          if (mounted) setState(() => _posts = []);
          return;
        }
      }

      dynamic query = _supabase
          .from('posts')
          .select('id, user_id, content, image_url, created_at')
          .eq('visibility', 'public');

      if (allowedUserIds != null) {
        query = query.inFilter('user_id', allowedUserIds);
      }

      final postRows = await query.order('created_at', ascending: false);
      final rows = postRows as List<dynamic>;
      final userIds = rows
          .map((row) => (row as Map<String, dynamic>)['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final postIds = rows
          .map((row) => (row as Map<String, dynamic>)['id']?.toString())
          .whereType<String>()
          .toList();

      final authors = <String, UserProfile>{};
      if (userIds.isNotEmpty) {
        final profileRows = await _supabase
            .from('profiles')
            .select('id, full_name, email, gender, user_type, status, avatar_url, created_at')
            .inFilter('id', userIds);

        for (final item in profileRows as List<dynamic>) {
          final row = item as Map<String, dynamic>;
          final id = row['id']?.toString();
          if (id == null) continue;
          authors[id] = UserProfile(
            id: id,
            fullName: row['full_name']?.toString() ?? 'ShapeRush User',
            email: row['email']?.toString() ?? '',
            gender: row['gender']?.toString() ?? '',
            userType: row['user_type']?.toString() ?? '',
            status: row['status']?.toString() ?? '',
            avatarUrl: row['avatar_url']?.toString(),
            createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          );
        }
      }

      final likeCounts = <String, int>{};
      final commentCounts = <String, int>{};
      final likedPostIds = <String>{};
      final currentUserId = _supabase.auth.currentUser?.id;
      if (postIds.isNotEmpty) {
        final likeRows = await _supabase
            .from('post_likes')
            .select('post_id, user_id')
            .inFilter('post_id', postIds);

        for (final item in likeRows as List<dynamic>) {
          final row = item as Map<String, dynamic>;
          final postId = row['post_id']?.toString();
          final userId = row['user_id']?.toString();
          if (postId == null) continue;
          likeCounts[postId] = (likeCounts[postId] ?? 0) + 1;
          if (userId == currentUserId) likedPostIds.add(postId);
        }

        final commentRows = await _supabase
            .from('post_comments')
            .select('post_id')
            .inFilter('post_id', postIds);
        for (final item in commentRows as List<dynamic>) {
          final postId =
              (item as Map<String, dynamic>)['post_id']?.toString();
          if (postId == null) continue;
          commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
        }
      }

      final posts = rows.map((item) {
        final row = item as Map<String, dynamic>;
        final userId = row['user_id']?.toString() ?? '';
        final postId = row['id']?.toString() ?? '';
        return SocialPost(
          id: postId,
          userId: userId,
          content: row['content']?.toString() ?? '',
          imageUrl: row['image_url']?.toString(),
          likeCount: likeCounts[postId] ?? 0,
          commentCount: commentCounts[postId] ?? 0,
          isLiked: likedPostIds.contains(postId),
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          author: authors[userId],
        );
      }).toList();

      if (mounted) setState(() => _posts = posts);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SocialPost> get _filteredPosts {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return _posts;
    return _posts.where((post) {
      final author = post.author?.fullName.toLowerCase() ?? '';
      return post.content.toLowerCase().contains(search) || author.contains(search);
    }).toList();
  }

  Future<void> _toggleLike(SocialPost post) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final wasLiked = post.isLiked;
    _replacePostLike(post.id, !wasLiked);
    try {
      if (wasLiked) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', userId);
      } else {
        await _supabase.from('post_likes').upsert(
          {
            'post_id': post.id,
            'user_id': userId,
          },
          onConflict: 'post_id,user_id',
          ignoreDuplicates: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _replacePostLike(post.id, wasLiked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update like: $error')),
      );
    }
  }

  void _replacePostLike(String postId, bool isLiked) {
    if (!mounted) return;
    setState(() {
      _posts = _posts.map((post) {
        if (post.id != postId) return post;
        return SocialPost(
          id: post.id,
          userId: post.userId,
          content: post.content,
          imageUrl: post.imageUrl,
          likeCount: (post.likeCount + (isLiked ? 1 : -1)).clamp(0, 1 << 31),
          commentCount: post.commentCount,
          isLiked: isLiked,
          createdAt: post.createdAt,
          author: post.author,
        );
      }).toList();
    });
  }

  Future<void> _openCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
    if (!mounted) return;
    if (created == true) {
      await _loadPosts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        onPressed: _openCreatePost,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        children: [
                          _buildTab('Feed', 0),
                          _buildTab('Following', 1),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: 'My public profile',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        final userId = _supabase.auth.currentUser?.id;
                        if (userId == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicProfilePage(userId: userId),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFE1D9FF),
                        backgroundImage: _currentUserAvatarUrl?.isNotEmpty == true
                            ? NetworkImage(_currentUserAvatarUrl!)
                            : null,
                        child: _currentUserAvatarUrl?.isNotEmpty == true
                            ? null
                            : Text(
                                _currentUserName?.trim().isNotEmpty == true
                                    ? _currentUserName!.trim()[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search users or posts...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Unable to load posts.'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadPosts, child: const Text('Try Again')),
          ],
        ),
      );
    }

    final posts = _filteredPosts;
    if (posts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            Icon(
              selectedTab == 1 ? Icons.people_outline : Icons.photo_library_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              selectedTab == 1
                  ? 'Follow people to see their posts here.'
                  : 'No posts found.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: posts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemBuilder: (context, index) {
          final post = posts[index];
          return GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ViewPostPage(post: post)),
              );
              if (mounted) await _loadPosts();
            },
            child: PostCard(
              post: post,
              onLike: () => _toggleLike(post),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedTab == index) return;
          setState(() => selectedTab = index);
          _loadPosts();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selectedTab == index
                ? Colors.deepPurpleAccent
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selectedTab == index ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
