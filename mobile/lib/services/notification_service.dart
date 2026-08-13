import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final String localName = await FlutterTimezone.getLocalTimezone();
      debugPrint('NotificationService: device timezone = $localName');
      tz.setLocalLocation(tz.getLocation(localName));
      debugPrint('NotificationService: tz.local = ${tz.local.name}');
    } catch (e) {
      debugPrint('NotificationService: failed to set local timezone: $e');
      // Fall back to UTC if the device timezone name is not recognized.
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final didInit = await _plugin.initialize(initSettings);
    debugPrint('NotificationService: initialize() returned $didInit');

    await _createAndroidNotificationChannel();

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    bool granted = true;

    if (androidImpl != null) {
      final notificationsGranted =
          await androidImpl.requestNotificationsPermission();
      final exactAlarmGranted = await androidImpl.requestExactAlarmsPermission();
      granted = (notificationsGranted ?? true) && (exactAlarmGranted ?? true);

      debugPrint(
        'NotificationService: notificationsGranted=$notificationsGranted exactAlarmGranted=$exactAlarmGranted',
      );
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosImpl != null) {
      final iosGranted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = granted && (iosGranted ?? true);
    }

    return granted;
  }

  Future<void> _createAndroidNotificationChannel() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl == null) return;

    const channel = AndroidNotificationChannel(
      'reminders_channel',
      'Reminders',
      description: 'ShapeRush reminder notifications',
      importance: Importance.high,
    );

    await androidImpl.createNotificationChannel(channel);
  }

  int _notificationIdFor(String reminderId) {
    return reminderId.hashCode & 0x7fffffff;
  }

  String _titleForType(String type) {
    switch (type) {
      case 'Hydration Reminder':
        return 'Time to hydrate 💧';
      case 'Rest Reminder':
        return 'Time to rest 🛌';
      case 'Meal Reminder':
        return 'Time for a meal 🍽️';
      case 'Exercise Reminder':
      default:
        return 'Time to work out 💪';
    }
  }

  String _bodyForType(String type) {
    switch (type) {
      case 'Hydration Reminder':
        return 'Drink some water to stay on track.';
      case 'Rest Reminder':
        return 'Take a break and let your body recover.';
      case 'Meal Reminder':
        return 'Don\'t forget to log your meal.';
      case 'Exercise Reminder':
      default:
        return 'Your ShapeRush workout is waiting for you.';
    }
  }

  Future<bool> _canUseExactAlarms() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return false;
    try {
      final canSchedule = await androidImpl.canScheduleExactNotifications();
      debugPrint('NotificationService: canScheduleExactNotifications = $canSchedule');
      return canSchedule ?? false;
    } catch (e) {
      debugPrint('NotificationService: canScheduleExactNotifications error: $e');
      return false;
    }
  }

  Future<void> scheduleReminder({
    required String reminderId,
    required String type,
    required TimeOfDay time,
  }) async {
    await init();

    final id = _notificationIdFor(reminderId);
    final scheduledTime = _nextInstanceOfTime(time);

    // Check if exact alarms are actually granted. On Android 14+,
    // zonedSchedule with exactAllowWhileIdle silently fails (no exception)
    // if the permission isn't granted, so we must check beforehand.
    final canExact = await _canUseExactAlarms();
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    debugPrint(
      'NotificationService: scheduling reminder $id "$type" at '
      '${scheduledTime.toIso8601String()} (${tz.local.name}) mode=$scheduleMode',
    );

    try {
      await _plugin.zonedSchedule(
        id,
        _titleForType(type),
        _bodyForType(type),
        scheduledTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminders_channel',
            'Reminders',
            channelDescription: 'ShapeRush reminder notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('NotificationService: reminder $id scheduled successfully');
    } on PlatformException catch (e, stack) {
      debugPrint(
        'NotificationService: schedule failed (${e.code}): $e',
      );
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> cancelReminder(String reminderId) async {
    await init();
    await _plugin.cancel(_notificationIdFor(reminderId));
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }
}
