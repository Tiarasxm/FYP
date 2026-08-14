import 'workout_plan.dart';

class ChatUser {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final List<String> tags;
  final bool priority;
  final String avatarText;

  final int age;
  final String gender;
  final String weight;
  final String height;
  final String activityLevel;
  final String fitnessGoal;
  final WorkoutPlan? activePlan;

  const ChatUser({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.tags,
    required this.priority,
    required this.avatarText,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    required this.activityLevel,
    required this.fitnessGoal,
    this.activePlan,
  });
}

class ChatMessage {
  final bool isMe;
  final String? text;
  final WorkoutPlan? plan;
  final String time;

  const ChatMessage({
    required this.isMe,
    this.text,
    this.plan,
    required this.time,
  });
}