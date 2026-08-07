import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool isLoading = true;
  bool isSaving = false;
  bool dailyReminderEnabled = true;

  final SupabaseClient supabase = Supabase.instance.client;

  final List<ReminderItem> reminders = [];

  static const List<String> reminderTypes = [
    "Exercise Reminder",
    "Hydration Reminder",
    "Rest Reminder",
    "Meal Reminder",
  ];

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() {
      isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      final settingResponse = await supabase
          .from('notification_settings')
          .select('daily_reminder_enabled')
          .eq('profile_id', userId)
          .maybeSingle();

      final remindersResponse = await supabase
          .from('notification_reminders')
          .select(
            'reminder_id, reminder_type, reminder_time, enabled, created_at',
          )
          .eq('profile_id', userId)
          .order('created_at', ascending: true);

      final rows = List<Map<String, dynamic>>.from(remindersResponse as List);

      if (!mounted) return;

      setState(() {
        dailyReminderEnabled =
            settingResponse?['daily_reminder_enabled'] == false ? false : true;

        reminders
          ..clear()
          ..addAll(
            rows.map((row) {
              return ReminderItem(
                id: row['reminder_id']?.toString() ?? '',
                type: row['reminder_type']?.toString() ?? 'Exercise Reminder',
                time: _parseTimeFromDb(row['reminder_time']),
                enabled: row['enabled'] == false ? false : true,
              );
            }),
          );
      });
    } catch (error) {
      _showMessage('Failed to load notifications: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  TimeOfDay _parseTimeFromDb(dynamic value) {
    final text = value?.toString() ?? '08:00';

    final parts = text.split(':');

    if (parts.length < 2) {
      return const TimeOfDay(hour: 8, minute: 0);
    }

    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  String _timeToDb(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _timeToDisplay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _saveDailyReminderEnabled(bool value) async {
    if (isSaving) return;

    final oldValue = dailyReminderEnabled;

    setState(() {
      dailyReminderEnabled = value;
      isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      await supabase.from('notification_settings').upsert(
        {
          'profile_id': userId,
          'daily_reminder_enabled': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'profile_id',
      );

      _showMessage('Notification setting saved.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        dailyReminderEnabled = oldValue;
      });

      _showMessage('Failed to save setting: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> addReminder() async {
    if (isSaving) return;

    setState(() {
      isSaving = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not signed in.');
      }

      const defaultType = 'Exercise Reminder';
      const defaultTime = TimeOfDay(hour: 8, minute: 0);

      final response = await supabase
          .from('notification_reminders')
          .insert({
            'profile_id': userId,
            'reminder_type': defaultType,
            'reminder_time': _timeToDb(defaultTime),
            'enabled': true,
          })
          .select('reminder_id, reminder_type, reminder_time, enabled')
          .single();

      if (!mounted) return;

      setState(() {
        reminders.add(
          ReminderItem(
            id: response['reminder_id']?.toString() ?? '',
            type: response['reminder_type']?.toString() ?? defaultType,
            time: _parseTimeFromDb(response['reminder_time']),
            enabled: response['enabled'] == false ? false : true,
          ),
        );
      });

      _showMessage('Reminder added.');
    } catch (error) {
      _showMessage('Failed to add reminder: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> updateReminderType(int index, String type) async {
    if (index < 0 || index >= reminders.length) return;

    final reminder = reminders[index];

    setState(() {
      reminders[index] = reminder.copyWith(type: type);
    });

    try {
      await supabase.from('notification_reminders').update({
        'reminder_type': type,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('reminder_id', reminder.id);

      _showMessage('Reminder updated.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        reminders[index] = reminder;
      });

      _showMessage('Failed to update reminder: $error', isError: true);
    }
  }

  Future<void> updateReminderTime(int index) async {
    if (index < 0 || index >= reminders.length) return;

    final reminder = reminders[index];

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: reminder.time,
    );

    if (selectedTime == null || !mounted) return;

    setState(() {
      reminders[index] = reminder.copyWith(time: selectedTime);
    });

    try {
      await supabase.from('notification_reminders').update({
        'reminder_time': _timeToDb(selectedTime),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('reminder_id', reminder.id);

      _showMessage('Reminder time updated.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        reminders[index] = reminder;
      });

      _showMessage('Failed to update time: $error', isError: true);
    }
  }

  Future<void> removeReminder(int index) async {
    if (index < 0 || index >= reminders.length) return;

    final reminder = reminders[index];

    setState(() {
      reminders.removeAt(index);
    });

    try {
      await supabase
          .from('notification_reminders')
          .delete()
          .eq('reminder_id', reminder.id);

      _showMessage('Reminder deleted.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        reminders.insert(index, reminder);
      });

      _showMessage('Failed to delete reminder: $error', isError: true);
    }
  }

  Future<void> toggleReminderEnabled(int index, bool value) async {
    if (index < 0 || index >= reminders.length) return;

    final reminder = reminders[index];

    setState(() {
      reminders[index] = reminder.copyWith(enabled: value);
    });

    try {
      await supabase.from('notification_reminders').update({
        'enabled': value,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('reminder_id', reminder.id);

      _showMessage('Reminder setting saved.');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        reminders[index] = reminder;
      });

      _showMessage('Failed to update reminder: $error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadNotificationSettings,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _CircleBackButton(
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Center(
                              child: Text(
                                "Notifications",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 38),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Choose the reminder type and time that fit your routine.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FC),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6E0FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none,
                                    size: 15,
                                    color: Colors.deepPurpleAccent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "Remind me daily",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.85,
                                  child: Switch(
                                    value: dailyReminderEnabled,
                                    activeTrackColor: Colors.deepPurpleAccent,
                                    activeThumbColor: Colors.white,
                                    onChanged: isSaving
                                        ? null
                                        : _saveDailyReminderEnabled,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (reminders.isEmpty)
                              _emptyReminderCard()
                            else
                              ...List.generate(
                                reminders.length,
                                (index) {
                                  return _reminderRow(index);
                                },
                              ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: isSaving ? null : addReminder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.deepPurpleAccent.withOpacity(0.5),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add,
                                        size: 16,
                                      ),
                                label: const Text(
                                  "Add Reminder",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _emptyReminderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'No reminders yet. Tap Add Reminder to create one.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade600,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _reminderRow(int index) {
    final reminder = reminders[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: reminder.enabled,
                activeTrackColor: Colors.deepPurpleAccent,
                activeThumbColor: Colors.white,
                onChanged: (value) {
                  toggleReminderEnabled(index, value);
                },
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 5,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FC),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: reminder.type,
                    isExpanded: true,
                    iconSize: 18,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black,
                    ),
                    items: reminderTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: reminder.enabled
                        ? (value) {
                            if (value == null) return;
                            updateReminderType(index, value);
                          }
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: reminder.enabled
                    ? () {
                        updateReminderTime(index);
                      }
                    : null,
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FC),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _timeToDisplay(reminder.time),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              onPressed: () => removeReminder(index),
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReminderItem {
  final String id;
  final String type;
  final TimeOfDay time;
  final bool enabled;

  const ReminderItem({
    required this.id,
    required this.type,
    required this.time,
    required this.enabled,
  });

  ReminderItem copyWith({
    String? id,
    String? type,
    TimeOfDay? time,
    bool? enabled,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      type: type ?? this.type,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CircleBackButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F3FC),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new,
          size: 15,
        ),
      ),
    );
  }
}