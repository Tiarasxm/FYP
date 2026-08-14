import 'user_profile.dart';

class SocialComment {
  final String id;
  final String postId;
  final String userId;
  final String content;
  final DateTime? createdAt;
  final UserProfile? author;

  const SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    this.createdAt,
    this.author,
  });
}
