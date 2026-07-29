class Exercise {
  final String name;
  final String detail;
  final String? exerciseId;
  final int? sets;
  final int? repMin;
  final int? repMax;
  final int? restSec;

  const Exercise({
    required this.name,
    required this.detail,
    this.exerciseId,
    this.sets,
    this.repMin,
    this.repMax,
    this.restSec,
  });
}

class WorkoutDay {
  final int dayNumber;
  final String title;
  final String duration;
  final int exerciseCount;
  final List<Exercise> exercises;

  const WorkoutDay({
    required this.dayNumber,
    required this.title,
    required this.duration,
    required this.exerciseCount,
    required this.exercises,
  });
}

class WorkoutPlan {
  final String title;
  final int days;
  final String duration;
  final List<String> tags;
  final List<WorkoutDay> workoutDays;

  const WorkoutPlan({
    required this.title,
    required this.days,
    required this.duration,
    required this.tags,
    required this.workoutDays,
  });
}

class PlanDayDraft {
  final int weekNumber;
  final int dayNumber;
  String dayName;
  bool isRestDay;
  List<Exercise> exercises;

  PlanDayDraft({
    required this.weekNumber,
    required this.dayNumber,
    this.dayName = '',
    this.isRestDay = false,
    List<Exercise>? exercises,
  }) : exercises = exercises ?? [];

  String get displayName {
    if (dayName.trim().isEmpty) {
      return 'Day $dayNumber';
    }
    return dayName.trim();
  }
}