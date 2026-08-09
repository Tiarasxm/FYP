import 'user_profile.dart';

class SocialPost {
  final String id;
  final String userId;
  final String content;
  final String? imageUrl;
  final String visibility;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final DateTime? createdAt;
  final UserProfile? author;

  const SocialPost({
    required this.id,
    required this.userId,
    required this.content,
    this.imageUrl,
    this.visibility = 'public',
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.createdAt,
    this.author,
  });
}
