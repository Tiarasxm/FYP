import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/client/social_post.dart';
import '../../models/client/user_profile.dart';
import 'edit_post_page.dart';
import 'post_card.dart';
import 'view_post_page.dart';

class PublicProfilePage extends StatefulWidget {
  final String? userId;

  const PublicProfilePage({super.key, this.userId});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final _supabase = Supabase.instance.client;
  UserProfile? _profile;
  List<SocialPost> _posts = [];
  String _bio = '';
  String? _avatarUrl;
  int _followers = 0;
  int _following = 0;
  bool _isFollowing = false;
  bool _isLoading = true;
  bool _isFollowSaving = false;
  String? _error;

  String? get _targetUserId =>
      widget.userId ?? Supabase.instance.client.auth.currentUser?.id;

  bool get _isOwnProfile =>
      _targetUserId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = _targetUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Profile not found.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profileRow = await _supabase
          .from('profiles')
          .select('id, full_name, email, gender, user_type, status, avatar_url, created_at')
          .eq('id', userId)
          .maybeSingle();
      if (profileRow == null) throw Exception('Profile not found.');

      final profile = UserProfile(
        id: profileRow['id'].toString(),
        fullName: profileRow['full_name']?.toString() ?? 'ShapeRush User',
        email: profileRow['email']?.toString() ?? '',
        gender: profileRow['gender']?.toString() ?? '',
        userType: profileRow['user_type']?.toString() ?? '',
        status: profileRow['status']?.toString() ?? '',
        avatarUrl: profileRow['avatar_url']?.toString(),
        createdAt: DateTime.tryParse(profileRow['created_at']?.toString() ?? ''),
      );

      String? avatarUrl = profile.avatarUrl;
      if (_isOwnProfile) {
        final metadata = _supabase.auth.currentUser?.userMetadata;
        avatarUrl = profile.avatarUrl ??
            metadata?['avatar_url']?.toString() ??
            metadata?['picture']?.toString();
      }

      var bio = '';
      if (profile.userType.toLowerCase() == 'fitness professional') {
        final professional = await _supabase
            .from('fitness_professional')
            .select('display_name, bio')
            .eq('profile_id', userId)
            .maybeSingle();
        bio = professional?['bio']?.toString() ?? '';
      }

      final postRows = await _supabase
          .from('posts')
          .select('id, user_id, content, image_url, created_at')
          .eq('user_id', userId)
          .eq('visibility', 'public')
          .order('created_at', ascending: false);

      final postIds = (postRows as List<dynamic>)
          .map((item) => (item as Map<String, dynamic>)['id']?.toString())
          .whereType<String>()
          .toList();
      final likeCounts = <String, int>{};
      final likedPosts = <String>{};
      final currentUserId = _supabase.auth.currentUser?.id;

      if (postIds.isNotEmpty) {
        final likeRows = await _supabase
            .from('post_likes')
            .select('post_id, user_id')
            .inFilter('post_id', postIds);
        for (final item in likeRows as List<dynamic>) {
          final row = item as Map<String, dynamic>;
          final postId = row['post_id']?.toString();
          if (postId == null) continue;
          likeCounts[postId] = (likeCounts[postId] ?? 0) + 1;
          if (row['user_id']?.toString() == currentUserId) {
            likedPosts.add(postId);
          }
        }
      }

      final posts = postRows.map((item) {
        final row = item;
        final postId = row['id']?.toString() ?? '';
        return SocialPost(
          id: postId,
          userId: userId,
          content: row['content']?.toString() ?? '',
          imageUrl: row['image_url']?.toString(),
          likeCount: likeCounts[postId] ?? 0,
          isLiked: likedPosts.contains(postId),
          createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          author: profile,
        );
      }).toList();

      final followerRows = await _supabase
          .from('follows')
          .select('follower_id')
          .eq('following_id', userId);
      final followingRows = await _supabase
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);

      var isFollowing = false;
      if (!_isOwnProfile && currentUserId != null) {
        isFollowing = (followerRows as List<dynamic>).any(
          (item) =>
              (item as Map<String, dynamic>)['follower_id']?.toString() ==
              currentUserId,
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _bio = bio;
        _avatarUrl = avatarUrl;
        _posts = posts;
        _followers = (followerRows as List<dynamic>).length;
        _following = (followingRows as List<dynamic>).length;
        _isFollowing = isFollowing;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    final targetUserId = _targetUserId;
    if (currentUserId == null || targetUserId == null || _isFollowSaving) return;

    final previous = _isFollowing;
    setState(() {
      _isFollowSaving = true;
      _isFollowing = !previous;
      _followers += previous ? -1 : 1;
    });

    try {
      if (previous) {
        await _supabase
            .from('follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', targetUserId);
      } else {
        await _supabase.from('follows').insert({
          'follower_id': currentUserId,
          'following_id': targetUserId,
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isFollowing = previous;
        _followers += previous ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update follow: $error')),
      );
    } finally {
      if (mounted) setState(() => _isFollowSaving = false);
    }
  }

  Future<void> _editPost(SocialPost post) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => EditPostPage(post: post)),
    );
    if (!mounted) return;
    if (result == true || result == 'deleted') {
      await _loadProfile();
    }
  }

  Future<void> _deletePost(SocialPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || post.userId != currentUserId) return;

    try {
      await _supabase
          .from('posts')
          .delete()
          .eq('id', post.id)
          .eq('user_id', currentUserId);
      if (!mounted) return;
      setState(() => _posts.removeWhere((item) => item.id == post.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Public Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _profileHeader()),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        sliver: _posts.isEmpty
                            ? const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 50),
                                  child: Center(child: Text('No posts yet.')),
                                ),
                              )
                            : SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final post = _posts[index];
                                    return Stack(
                                      children: [
                                        Positioned.fill(
                                          child: GestureDetector(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ViewPostPage(post: post),
                                              ),
                                            ),
                                            child: PostCard(post: post),
                                          ),
                                        ),
                                        if (_isOwnProfile)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Material(
                                              color: Colors.white.withValues(
                                                alpha: 0.92,
                                              ),
                                              shape: const CircleBorder(),
                                              child: PopupMenuButton<String>(
                                                tooltip: 'Manage post',
                                                icon: const Icon(
                                                  Icons.more_horiz,
                                                  size: 20,
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'edit') {
                                                    _editPost(post);
                                                  } else if (value == 'delete') {
                                                    _deletePost(post);
                                                  }
                                                },
                                                itemBuilder: (context) => const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.edit_outlined),
                                                        SizedBox(width: 10),
                                                        Text('Edit Post'),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete_outline,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 10),
                                                        Text(
                                                          'Delete Post',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                  childCount: _posts.length,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 0.68,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _profileHeader() {
    final name = _profile?.fullName ?? 'ShapeRush User';
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          CircleAvatar(
            radius: 43,
            backgroundColor: const Color(0xFFE1D9FF),
            backgroundImage: _avatarUrl?.isNotEmpty == true
                ? NetworkImage(_avatarUrl!)
                : null,
            child: _avatarUrl?.isNotEmpty == true
                ? null
                : Text(
                    name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 30,
                      color: Colors.deepPurple,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              PublicProfileStat(value: '${_posts.length}', label: 'POSTS'),
              PublicProfileStat(value: '$_followers', label: 'FOLLOWERS'),
              PublicProfileStat(value: '$_following', label: 'FOLLOWING'),
            ],
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isFollowSaving ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing
                      ? Colors.grey.shade200
                      : Colors.deepPurpleAccent,
                  foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                ),
                child: Text(_isFollowing ? 'Following' : 'Follow'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('About', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _bio.trim().isEmpty ? 'No bio available.' : _bio,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 22),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Posts', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unable to load profile.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadProfile, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class PublicProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const PublicProfileStat({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      ],
    );
  }
}
