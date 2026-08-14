import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/client/social_comment.dart';
import '../../models/client/social_post.dart';
import '../../models/client/user_profile.dart';
import 'public_profile_page.dart';
import 'report_dialog.dart';
import '../../theme/app_theme.dart';

class ViewPostPage extends StatelessWidget {
  final SocialPost? post;

  const ViewPostPage({super.key, this.post});

  void openPublicProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(userId: post?.userId),
      ),
    );
  }

  Future<void> reportPost(BuildContext context) async {
    final item = post;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (item == null || currentUserId == null || item.userId == currentUserId) {
      return;
    }
    final submitted = await showSocialReportDialog(
      context: context,
      contentType: 'post',
      reportedUserId: item.userId,
      postId: item.id,
    );
    if (submitted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post reported successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName = post?.author?.fullName.trim();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios, size: 18),
                  ),
                  GestureDetector(
                    onTap: () => openPublicProfile(context),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primarySoft,
                    backgroundImage: post?.author?.avatarUrl?.isNotEmpty == true
                        ? NetworkImage(post!.author!.avatarUrl!)
                        : null,
                    child: post?.author?.avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            authorName?.isNotEmpty == true
                                ? authorName![0].toUpperCase()
                                : '?',
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => openPublicProfile(context),
                      child: Text(
                        authorName?.isNotEmpty == true
                            ? authorName!
                            : 'ShapeRush User',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (post != null) _FollowButton(targetUserId: post!.userId),
                  if (post != null &&
                      post!.userId !=
                          Supabase.instance.client.auth.currentUser?.id)
                    IconButton(
                      tooltip: 'Report post',
                      onPressed: () => reportPost(context),
                      icon: const Icon(Icons.flag_outlined),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (post?.imageUrl?.isNotEmpty == true)
                      Image.network(
                        post!.imageUrl!,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 300,
                          color: AppColors.border,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      )
                    else
                      Container(height: 300, color: AppColors.border),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post?.content.isNotEmpty == true
                                ? post!.content
                                : 'Fitness update',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            post?.createdAt == null
                                ? 'Recently posted'
                                : 'Posted on ${post!.createdAt!.day}/${post!.createdAt!.month}/${post!.createdAt!.year}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            "Comments",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (post != null) _CommentsPanel(postId: post!.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: post == null
                    ? const SizedBox.shrink()
                    : _PostLikeButton(post: post!),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _CommentsPanel extends StatefulWidget {
  final String postId;

  const _CommentsPanel({required this.postId});

  @override
  State<_CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends State<_CommentsPanel> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  List<SocialComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final rows = await _supabase
          .from('post_comments')
          .select('id, post_id, user_id, content, created_at')
          .eq('post_id', widget.postId)
          .order('created_at');

      final userIds = rows
          .map<String>((row) => row['user_id'] as String)
          .toSet()
          .toList();
      final profiles = userIds.isEmpty
          ? <dynamic>[]
          : await _supabase
              .from('profiles')
              .select('id, full_name, email, gender, user_type, status, avatar_url, created_at')
              .inFilter('id', userIds);
      final profileById = <String, UserProfile>{};
      for (final profile in profiles) {
        final id = profile['id'] as String;
        profileById[id] = UserProfile(
          id: id,
          fullName: (profile['full_name'] as String?) ?? 'ShapeRush User',
          email: (profile['email'] as String?) ?? '',
          gender: (profile['gender'] as String?) ?? '',
          userType: (profile['user_type'] as String?) ?? '',
          status: (profile['status'] as String?) ?? '',
          avatarUrl: profile['avatar_url'] as String?,
          createdAt: DateTime.tryParse((profile['created_at'] as String?) ?? ''),
        );
      }

      if (!mounted) return;
      setState(() {
        _comments = rows.map<SocialComment>((row) {
          final userId = row['user_id'] as String;
          return SocialComment(
            id: row['id'] as String,
            postId: row['post_id'] as String,
            userId: userId,
            content: row['content'] as String,
            createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
            author: profileById[userId],
          );
        }).toList();
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to load comments.';
      });
    }
  }

  Future<void> _sendComment() async {
    final userId = _supabase.auth.currentUser?.id;
    final content = _controller.text.trim();
    if (userId == null || content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await _supabase.from('post_comments').insert({
        'post_id': widget.postId,
        'user_id': userId,
        'content': content,
      });
      _controller.clear();
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to post comment: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteComment(SocialComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This comment will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.from('post_comments').delete().eq('id', comment.id);
      await _loadComments();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete comment: $error')),
        );
      }
    }
  }

  Future<void> _editComment(SocialComment comment) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || comment.userId != currentUserId) return;

    final updatedContent = await showDialog<String>(
      context: context,
      builder: (_) => _EditCommentDialog(initialContent: comment.content),
    );
    if (!mounted) return;
    if (updatedContent == null || updatedContent == comment.content) return;

    try {
      await _supabase
          .from('post_comments')
          .update({
            'content': updatedContent,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', comment.id)
          .eq('user_id', currentUserId);
      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment updated successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update comment: $error')),
        );
      }
    }
  }

  void _openProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicProfilePage(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          )
        else if (_error != null)
          TextButton.icon(
            onPressed: _loadComments,
            icon: const Icon(Icons.refresh),
            label: Text(_error!),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'No comments yet.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ..._comments.map(_buildComment),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.pageBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _isSending ? null : _sendComment,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComment(SocialComment comment) {
    final name = comment.author?.fullName.trim();
    final isOwner = comment.userId == _supabase.auth.currentUser?.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openProfile(comment.userId),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primarySoft,
              backgroundImage: comment.author?.avatarUrl?.isNotEmpty == true
                  ? NetworkImage(comment.author!.avatarUrl!)
                  : null,
              child: comment.author?.avatarUrl?.isNotEmpty == true
                  ? null
                  : Text(
                      name?.isNotEmpty == true ? name![0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 12),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openProfile(comment.userId),
                  child: Text(
                    name?.isNotEmpty == true ? name! : 'ShapeRush User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(comment.content, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          if (isOwner)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Edit comment',
                  onPressed: () => _editComment(comment),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete comment',
                  onPressed: () => _deleteComment(comment),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EditCommentDialog extends StatefulWidget {
  final String initialContent;

  const _EditCommentDialog({required this.initialContent});

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final content = _controller.text.trim();
    if (content.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.pop(context, content);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit comment'),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 500,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            hintText: 'Write your comment...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _FollowButton extends StatefulWidget {
  final String targetUserId;

  const _FollowButton({required this.targetUserId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final _supabase = Supabase.instance.client;
  String _followStatus = 'none';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId == widget.targetUserId) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final row = await _supabase
          .from('follows')
          .select('status')
          .eq('follower_id', userId)
          .eq('following_id', widget.targetUserId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _followStatus = row?['status']?.toString() ?? 'none';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _isLoading) return;

    final previous = _followStatus;
    setState(() => _isLoading = true);
    try {
      if (previous == 'accepted' || previous == 'pending') {
        await _supabase.rpc('unfollow', params: {'p_target_uuid': widget.targetUserId});
        if (mounted) setState(() => _followStatus = 'none');
      } else {
        final result = await _supabase.rpc(
          'request_follow',
          params: {'p_target_uuid': widget.targetUserId},
        );
        final status = result?.toString() ?? 'accepted';
        if (mounted) {
          setState(() => _followStatus = status);
          if (status == 'pending') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Follow request sent.')),
            );
          }
        }
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _followStatus = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update follow: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_supabase.auth.currentUser?.id == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    final isFollowing = _followStatus == 'accepted';
    final isPending = _followStatus == 'pending';
    final label = isFollowing
        ? 'Following'
        : isPending
            ? 'Requested'
            : 'Follow';
    final bgColor = (isFollowing || isPending) ? AppColors.border : AppColors.primary;
    final fgColor = (isFollowing || isPending) ? AppColors.textPrimary : Colors.white;

    return ElevatedButton(
      onPressed: _isLoading ? null : _toggleFollow,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
      ),
      child: Text(label),
    );
  }
}

class _PostLikeButton extends StatefulWidget {
  final SocialPost post;

  const _PostLikeButton({required this.post});

  @override
  State<_PostLikeButton> createState() => _PostLikeButtonState();
}

class _PostLikeButtonState extends State<_PostLikeButton> {
  final _supabase = Supabase.instance.client;
  late bool _isLiked = widget.post.isLiked;
  late int _likeCount = widget.post.likeCount;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final rows = await _supabase
          .from('post_likes')
          .select('user_id')
          .eq('post_id', widget.post.id);
      if (!mounted) return;
      setState(() {
        _likeCount = rows.length;
        _isLiked = rows.any((row) => row['user_id']?.toString() == userId);
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _isSaving) return;

    final previous = _isLiked;
    setState(() {
      _isSaving = true;
      _isLiked = !previous;
      _likeCount = (_likeCount + (_isLiked ? 1 : -1)).clamp(0, 1 << 31);
    });

    try {
      if (previous) {
        await _supabase
            .from('post_likes')
            .delete()
            .eq('post_id', widget.post.id)
            .eq('user_id', userId);
      } else {
        await _supabase.from('post_likes').upsert(
          {
            'post_id': widget.post.id,
            'user_id': userId,
          },
          onConflict: 'post_id,user_id',
          ignoreDuplicates: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLiked = previous;
        _likeCount = (_likeCount + (previous ? 1 : -1)).clamp(0, 1 << 31);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update like: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _isSaving || _isLoading ? null : _toggleLike,
          icon: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? Colors.red : AppColors.textMuted,
          ),
        ),
        Text('$_likeCount'),
      ],
    );
  }
}
