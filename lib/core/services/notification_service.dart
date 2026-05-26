import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Timezone data initialize karein (Scheduled notification ke liye compulsory)
    tz.initializeTimeZones();

    // 1. Android settings define karein
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. iOS/Darwin settings define karein (Zaroori hai initialization ke liye)
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    // 3. Dono ko InitializationSettings wrapper mein daalein
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidSettings,
      iOS: iosSettings, // Agar iOS settings nahi dalenge toh error aayega
    );

    // 4. Ab plugin ko initialize karein
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Jab user notification pe click kare tab kya ho (Optional)
        print("Notification Clicked: ${response.payload}");
      },
    );
  }

  static Future<void> scheduleTaskReminder(
      int id, String title, DateTime taskTime) async {
    // Task time se 10 minute pehle ka time calculate karein
    final scheduleTime = tz.TZDateTime.from(
      taskTime.subtract(const Duration(minutes: 10)),
      tz.local,
    );

    if (scheduleTime.isAfter(DateTime.now())) {
      await _notificationsPlugin.zonedSchedule(
        id,
        "Task Reminder (VTAP)",
        "Aapka task '$title' 10 min mein shuru hone wala hai.",
        scheduleTime,
        const NotificationDetails(
          android: AndroidNotificationDetails('task_channel', 'Task Reminders',
              importance: Importance.max, priority: Priority.high),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
