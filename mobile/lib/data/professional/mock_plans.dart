import '../../models/professional/workout_plan.dart';

WorkoutPlan buildMockPlan({
  required String title,
  int days = 30,
}) {
  return WorkoutPlan(
    title: title,
    days: days,
    
    tags: const ['Full Body', 'Fat Loss', 'Strength'],
    workoutDays: const [
      WorkoutDay(
        dayNumber: 1,
        title: 'Day 1: Full Body Strength',
        
        exerciseCount: 6,
        exercises: [
          Exercise(name: 'Barbell Squats', detail: '3 × 10-12 • 60s rest'),
          Exercise(name: 'Barbell Bench Press', detail: '3 × 10-12 • 60s rest'),
          Exercise(name: 'Barbell Bent Over Row', detail: '3 × 10-12 • 60s rest'),
          Exercise(name: 'Triceps Dips', detail: '3 × 10-12 • 60s rest'),
          Exercise(name: 'Leg Raises', detail: '3 × 8-10 • 45s rest'),
          Exercise(name: 'Sumo Squats', detail: '3 × 10-12 • 60s rest'),
        ],
      ),
    ],
  );
}

final List<WorkoutPlan> publicPlans = [
  buildMockPlan(title: '30-Day Full Body Fat Burn'),
  buildMockPlan(title: '30-Day Upper Body Strength'),
  buildMockPlan(title: '14-Day Lower Body Blast', days: 14),
  buildMockPlan(title: '7-Day Core Starter', days: 7),
];

final List<WorkoutPlan> privatePlans = [
  buildMockPlan(title: '30-Day Full Body Fat Burn'),
  buildMockPlan(title: '30-Day Upper Body Strength'),
  buildMockPlan(title: '14-Day Lower Body Blast', days: 14),
  buildMockPlan(title: '21-Day Beginner Plan', days: 21),
  buildMockPlan(title: '10-Day Fat Loss Plan', days: 10),
  buildMockPlan(title: 'Push Pull Legs Plan'),
  buildMockPlan(title: 'Home Workout Plan'),
];