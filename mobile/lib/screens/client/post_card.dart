import 'package:flutter/material.dart';

import '../../models/client/social_post.dart';
import '../../theme/app_theme.dart';

class PostCard extends StatelessWidget {
  final SocialPost? post;
  final VoidCallback? onLike;

  const PostCard({super.key, this.post, this.onLike});

  @override
  Widget build(BuildContext context) {
    final item = post;
    final authorName = item?.author?.fullName.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Expanded(
            flex: 65,
            child: _PostImage(imageUrl: item?.imageUrl),
          ),
          Expanded(
            flex: 35,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item?.content.isNotEmpty == true
                        ? item!.content
                        : 'Fitness update',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.15),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.primarySoft,
                        backgroundImage: item?.author?.avatarUrl?.isNotEmpty == true
                            ? NetworkImage(item!.author!.avatarUrl!)
                            : null,
                        child: item?.author?.avatarUrl?.isNotEmpty == true
                            ? null
                            : Text(
                                authorName?.isNotEmpty == true
                                    ? authorName![0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.deepPurple,
                                ),
                              ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          authorName?.isNotEmpty == true
                              ? authorName!
                              : 'ShapeRush User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${item?.commentCount ?? 0}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            item?.isLiked == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: item?.isLiked == true
                                ? Colors.red
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${item?.likeCount ?? 0}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String? imageUrl;

  const _PostImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) return _placeholder();

    return SizedBox.expand(
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (_, __, ___) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.border,
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppColors.textMuted),
      ),
    );
  }
}
