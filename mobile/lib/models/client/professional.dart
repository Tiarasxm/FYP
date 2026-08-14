class Professional {
  final String? profileId;
  final String name;
  final String specialties;
  final double rating;
  final int reviewCount;
  final int yearsExp;
  final String? bio;
  final String? avatarUrl;

  const Professional({
    this.profileId,
    required this.name,
    required this.specialties,
    required this.rating,
    required this.reviewCount,
    this.yearsExp = 10,
    this.bio,
    this.avatarUrl,
  });

  factory Professional.fromSupabase(Map<String, dynamic> row) {
    final fp = row;
    final profile = row['profiles'] as Map<String, dynamic>?;
    final specs = fp['specializations']?.toString() ?? '';
    final experience = fp['experience']?.toString() ?? '';

    int yearsExp = 0;
    final expMatch = RegExp(r'(\d+)').firstMatch(experience);
    if (expMatch != null) {
      yearsExp = int.tryParse(expMatch.group(1)!) ?? 0;
    }

    final avgRating = (fp['avg_rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = (fp['review_count'] as num?)?.toInt() ?? 0;
    final url = profile?['avatar_url']?.toString().trim();

    return Professional(
      profileId: fp['profile_id']?.toString(),
      name: profile?['full_name']?.toString() ?? fp['display_name']?.toString() ?? 'Unknown',
      specialties: specs,
      rating: avgRating,
      reviewCount: reviewCount,
      yearsExp: yearsExp,
      bio: fp['bio']?.toString(),
      avatarUrl: (url != null && url.isNotEmpty) ? url : null,
    );
  }
}

class Review {
  final String reviewer;
  final double rating;
  final String text;

  const Review({
    required this.reviewer,
    required this.rating,
    required this.text,
  });
}

class ChatMessage {
  final String text;
  final bool fromMe;
  final String? planTitle;

  const ChatMessage({
    required this.text,
    this.fromMe = false,
    this.planTitle,
  });
}
