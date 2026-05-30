import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    // 1. Android settings define karein
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. iOS/Darwin settings define karein
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    // 3. Dono ko InitializationSettings wrapper mein daalein
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 4. Initialize plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification Clicked: ${response.payload}");
      },
    );

    // 🔥 FIXED: Android notification channel explicitly create karein!
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'task_channel', // Id (Must match exactly what you use in zonedSchedule)
      'Task Reminders', // Title visible to user in app settings
      description: 'This channel is used for VTAP task reminders.',
      importance: Importance.max,
      playSound: true,
    );

    // Resolve platform specific implementation and create channel
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required DateTime taskTime,
    required String frequency,
  }) async {
    final scheduleTime = tz.TZDateTime.from(
      taskTime.subtract(const Duration(minutes: 3)),
      tz.local,
    );

    var targetScheduleTime = scheduleTime;
    final freq = frequency.toLowerCase().trim();
    final nowTz = tz.TZDateTime.now(tz.local);

    if (targetScheduleTime.isBefore(nowTz)) {
      if (freq == "daily") {
        targetScheduleTime = targetScheduleTime.add(const Duration(days: 1));
      } else if (freq == "weekly") {
        targetScheduleTime = targetScheduleTime.add(const Duration(days: 7));
      }
    }

    if (targetScheduleTime.isAfter(nowTz)) {
      await _notificationsPlugin.zonedSchedule(
        id,
        "Task Reminder (VTAP)",
        "Aapka task '$title' 3 min mein shuru hone wala hai.",
        targetScheduleTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel', // Matches the channel created in init()
            'Task Reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(), // Added for fallback safety
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: freq == "daily"
            ? DateTimeComponents.time
            : (freq == "weekly" ? DateTimeComponents.dayOfWeekAndTime : null),
      );
      debugPrint("Notification scheduled successfully ($frequency) for: $targetScheduleTime");
    } else {
      debugPrint("Warning: Scheduled time is in the past! Notification not set.");
    }
  }
}
