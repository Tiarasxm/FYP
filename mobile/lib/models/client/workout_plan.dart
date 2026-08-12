class WorkoutPlan {
  final String title;
  final String duration;
  
  final List<String> tags;
  final bool active;
  final List<String> categories;
  final String createdBy;
  bool bookmarked;

  WorkoutPlan({
    required this.title,
    required this.duration,
    
    required this.tags,
    this.active = false,
    this.categories = const [],
    this.createdBy = 'ShapeRush',
    this.bookmarked = false,
  });
}
