class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String gender;
  final String userType;
  final String status;
  final String? avatarUrl;
  final DateTime? createdAt;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.gender,
    required this.userType,
    required this.status,
    this.avatarUrl,
    required this.createdAt,
    required this.avatarUrl,
  });

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? gender,
    String? userType,
    String? status,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      userType: userType ?? this.userType,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
