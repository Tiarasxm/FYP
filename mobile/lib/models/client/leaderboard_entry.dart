class LeaderboardEntry {
  final int rank;
  final String name;
  final int steps;
  final bool isMe;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.steps,
    this.isMe = false,
  });
}
