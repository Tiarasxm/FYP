class HistoryEntry {
  final String title;
  final String when;
  final String meta;

  const HistoryEntry({
    required this.title,
    required this.when,
    this.meta = '45 min • 6 exercises',
  });
}
