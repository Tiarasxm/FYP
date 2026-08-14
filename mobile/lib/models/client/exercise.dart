class Exercise {
  final String name;
  final int sets;
  final String reps;
  final int restSeconds;

  const Exercise({
    required this.name,
    required this.sets,
    required this.reps,
    this.restSeconds = 60,
  });

  String get meta => '$sets × $reps • ${restSeconds}s rest';
}

class ExerciseSet {
  String kg;
  String reps;
  bool done;

  ExerciseSet({this.kg = '', this.reps = '12', this.done = false});
}
