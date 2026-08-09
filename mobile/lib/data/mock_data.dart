import 'package:flutter/material.dart';

import '../models/client/achievement.dart';
import '../models/client/exercise.dart';
import '../models/client/history_entry.dart';
import '../models/client/leaderboard_entry.dart';
import '../models/client/menu_item.dart';
import '../models/client/nutrition.dart';
import '../models/client/professional.dart';
import '../models/client/workout_plan.dart';
import '../theme/app_theme.dart';

class MockData {
  // Home
  static const String userName = 'Christopher';
  static const String dateLabel = 'Saturday 23 May';

  static const int steps = 4580;
  static const int heartRate = 108;
  static const int weeklyVolume = 1200;
  static const int kcalBurned = 330;
  static const int kcalGoal = 500;

  static const String todaysPlanTitle = 'Full Body Strength';
  static const String todaysPlanMeta = '~45 min • 6 exercises';

  static const List<MenuItem> homeMenu = [
    MenuItem(label: 'Progress', icon: Icons.track_changes),
    MenuItem(label: 'Leaderboard', icon: Icons.groups),
    MenuItem(label: 'My Achievements', icon: Icons.emoji_events),
    MenuItem(label: 'Saved Workout Plans', icon: Icons.bookmark),
    MenuItem(label: 'Workout History', icon: Icons.history),
  ];

  // Workout
  static const List<String> workoutFilters = [
    'All',
    'Nutrition',
    'Strength',
    'Weight Loss',
    'HIIT',
  ];

  static WorkoutPlan activePlan() => WorkoutPlan(
        title: '30-Day Full Body Fat Burn',
        duration: '30 Days',
        sessionLength: '~45 min',
        tags: const ['Full Body', 'Fat Loss', 'Strength'],
        active: true,
        bookmarked: true,
        categories: const ['Strength', 'Weight Loss'],
      );

  static List<WorkoutPlan> freePlans() => [
        WorkoutPlan(
          title: '30-Day Full Body Fat Burn',
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          categories: const ['Strength', 'Weight Loss'],
        ),
        WorkoutPlan(
          title: 'Beginner HIIT',
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          categories: const ['HIIT', 'Weight Loss'],
        ),
        WorkoutPlan(
          title: 'Morning Yoga',
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          categories: const ['Nutrition'],
        ),
        WorkoutPlan(
          title: 'Upper Body Blast',
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          categories: const ['Strength'],
        ),
      ];

  // Nutrition
  static const int caloriesConsumed = 730;
  static const int caloriesGoal = 1600;

  static const List<Macro> macros = [
    Macro(name: 'Protein', current: 62, target: 108, color: AppColors.red),
    Macro(name: 'Carbs', current: 92, target: 180, color: AppColors.cyan),
    Macro(name: 'Fat', current: 37, target: 60, color: AppColors.green),
  ];

  static const int waterConsumed = 900;
  static const int waterGoal = 2000;

  static const List<Meal> meals = [
    Meal(
      name: 'Breakfast',
      calories: 685,
      protein: 39,
      carbs: 92,
      fat: 32,
      icon: Icons.breakfast_dining,
    ),
    Meal(
      name: 'Lunch',
      calories: 540,
      protein: 34,
      carbs: 61,
      fat: 18,
      icon: Icons.lunch_dining,
    ),
  ];

  // Fitness plan
  static const String currentDayLabel = 'Day 1: Full Body Strength';
  static const String currentDayMeta = '~45 min • 6 exercises';

  static const List<Exercise> dayExercises = [
    Exercise(name: 'Barbell Squats', sets: 3, reps: '10-12'),
    Exercise(name: 'Barbell Bench Press', sets: 3, reps: '10-12'),
    Exercise(name: 'Barbell Bent Over Row', sets: 3, reps: '10-12'),
    Exercise(name: 'Triceps Dips', sets: 3, reps: '10-12'),
    Exercise(name: 'Leg Raises', sets: 3, reps: '8-10', restSeconds: 45),
    Exercise(name: 'Sumo Squats', sets: 3, reps: '10-12'),
  ];

  // Progress
  static const List<int> weeklySteps = [9500, 4200, 3100, 6800, 12456, 8900, 7200];
  static const List<int> weeklyCalories = [420, 310, 380, 460, 456, 510, 390];
  static const List<String> weekDays = ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed'];

  // Leaderboard
  static const List<LeaderboardEntry> leaderboard = [
    LeaderboardEntry(rank: 1, name: 'David Bernard', steps: 50324),
    LeaderboardEntry(rank: 2, name: 'Sam Wilson', steps: 50024),
    LeaderboardEntry(rank: 3, name: 'Dakota Brooke', steps: 47764),
    LeaderboardEntry(rank: 4, name: 'Sam Wilson', steps: 50024),
    LeaderboardEntry(rank: 5, name: 'Sam Wilson', steps: 50024),
    LeaderboardEntry(rank: 6, name: 'Sam Wilson', steps: 50024),
    LeaderboardEntry(rank: 7, name: 'Sam Wilson', steps: 50024),
  ];

  static const LeaderboardEntry myPosition =
      LeaderboardEntry(rank: 18, name: 'Christopher Heron', steps: 2478, isMe: true);

  // Achievements
  static const List<Achievement> achievements = [
    Achievement(
      label: '3-Day Streak',
      description: 'Complete workouts on 3 days in a row.',
      icon: Icons.local_fire_department,
      color: AppColors.amber,
      achieved: true,
    ),
    Achievement(
      label: '7-Day Streak',
      description: 'Complete workouts on 7 days in a row.',
      icon: Icons.local_fire_department,
      color: AppColors.amber,
    ),
    Achievement(
      label: '30-Day Streak',
      description: 'Complete workouts on 30 days in a row.',
      icon: Icons.whatshot,
      color: AppColors.amber,
    ),
    Achievement(
      label: '100-Day Streak',
      description: 'Complete workouts on 100 days in a row.',
      icon: Icons.ac_unit,
      color: AppColors.blue,
    ),
    Achievement(
      label: 'Completed First Program',
      description: 'Finish every training day in an active plan.',
      icon: Icons.emoji_events,
      color: AppColors.primary,
    ),
  ];

  // Workout history
  static const List<HistoryEntry> workoutHistory = [
    HistoryEntry(title: 'Upper Body Strength', when: 'Yesterday'),
    HistoryEntry(title: 'Upper Body Strength', when: '2 days ago'),
    HistoryEntry(title: 'Full Body Strength', when: '3 days ago'),
    HistoryEntry(title: 'Upper Body Strength', when: '5 days ago'),
    HistoryEntry(title: 'Lower Body Strength', when: '6 days ago'),
    HistoryEntry(title: 'Lower Body Strength', when: '7 days ago'),
    HistoryEntry(title: 'Upper Body Strength', when: '8 days ago'),
    HistoryEntry(title: 'Full Body Strength', when: '10 days ago'),
    HistoryEntry(title: 'Upper Body Strength', when: '11 days ago'),
    HistoryEntry(title: 'Upper Body Strength', when: '12 days ago'),
    HistoryEntry(title: 'Full Body Strength', when: '12 days ago'),
    HistoryEntry(title: 'Full Body Strength', when: '13 days ago'),
    HistoryEntry(title: 'Upper Body Strength', when: '1 week ago'),
  ];

  // Fitness professionals
  static const List<String> professionalFilters = [
    'All',
    'Nutrition',
    'Strength',
    'Weight Loss',
    'HIIT',
  ];

  static const List<Professional> professionals = [
    Professional(
        name: 'Wade Warren',
        specialties: 'Nutrition • Strength',
        rating: 5.0,
        reviewCount: 6),
    Professional(
        name: 'Bessie Cooper',
        specialties: 'Nutrition • Yoga',
        rating: 4.5,
        reviewCount: 23),
    Professional(
        name: 'Kevin Bernard',
        specialties: 'HIIT • Strength',
        rating: 5.0,
        reviewCount: 6),
    Professional(
        name: 'Jane Mcgee',
        specialties: 'Nutrition • Strength',
        rating: 4.7,
        reviewCount: 9),
    Professional(
        name: 'Mike Williamson',
        specialties: 'Strength • Weight Loss',
        rating: 4.8,
        reviewCount: 14),
  ];

  static const String professionalAbout =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do '
      'eiusmod tempor incididunt ut labore et dolore magna.';

  static const List<Review> reviews = [
    Review(
        reviewer: 'Christopher',
        rating: 5.0,
        text:
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna.'),
    Review(
        reviewer: 'Christopher',
        rating: 5.0,
        text:
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna.'),
    Review(
        reviewer: 'Christopher',
        rating: 5.0,
        text:
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna.'),
    Review(
        reviewer: 'Christopher',
        rating: 5.0,
        text:
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna.'),
  ];

  static const List<ChatMessage> chatMessages = [
    ChatMessage(text: 'Hi, Wade!', fromMe: true),
    ChatMessage(
        text: 'Can you help me create a 30-day weight loss program?',
        fromMe: true),
    ChatMessage(text: "Sure, let me know if you need any adjustments."),
    ChatMessage(
        text: '',
        planTitle: '30-Day Full Body Fat Burn'),
  ];

  // AI food scan
  static const String scannedFoodName = 'Tuna Poke Bowl';
  static const int scannedCalories = 685;
  static const List<(String, int)> scannedIngredients = [
    ('Rice', 205),
    ('Tuna', 275),
    ('Green beans', 15),
    ('Avocado', 15),
  ];

  // Saved plans
  static List<WorkoutPlan> savedPlans() => [
        WorkoutPlan(
          title: '30-Day Full Body Fat Burn',
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          bookmarked: true,
          createdBy: 'ShapeRush',
        ),
        WorkoutPlan(
          title: 'Morning Yoga',
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          bookmarked: true,
          createdBy: 'ShapeRush',
        ),
        WorkoutPlan(
          title: "Elise's Fitness Plan",
          duration: '30 Days',
          sessionLength: '~45 min',
          tags: const ['Full Body', 'Fat Loss', 'Strength'],
          bookmarked: true,
          createdBy: 'Wade Warren',
        ),
      ];
}
