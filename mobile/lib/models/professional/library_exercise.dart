class LibraryExercise {
  final String? id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final int? repMin;
  final int? repMax;
  final int? restSec;
  final bool byMe;

  const LibraryExercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.repMin,
    this.repMax,
    this.restSec,
    this.byMe = false,
  });

  String get repsLabel {
    if (repMin == null) return '';
    if (repMax == null || repMax == repMin) return '$repMin reps';
    return '$repMin-$repMax reps';
  }
}