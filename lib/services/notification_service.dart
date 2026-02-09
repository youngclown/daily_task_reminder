import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:typed_data';
import 'dart:io' show Platform;
import '../models/task.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Check if the platform supports notifications
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS;

  NotificationService._init();

  Future<void> initialize() async {
    if (!isSupported) {
      print('Notifications not supported on ${Platform.operatingSystem}, skipping initialization');
      return;
    }

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          // Handle notification tap
        },
      );
      _initialized = true;
    } catch (e) {
      print('Failed to initialize notifications: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (!isSupported) {
      print('Notifications not supported on ${Platform.operatingSystem}, skipping permission request');
      return;
    }

    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (!isSupported || !_initialized) {
      print('Notifications not supported or not initialized, skipping schedule');
      return;
    }
    if (task.isCompleted) return;

    try {
      // 1. Cancel existing notifications
      await cancelTaskReminder(task.id!);

      // 2. Calculate next scheduled time
      final nextScheduledTime = _calculateNextScheduledTime(task);

      // 3. Schedule main notification
      await _scheduleMainNotification(task, nextScheduledTime);

      // 4. Schedule reminder notification (X minutes before)
      await _scheduleReminderNotification(task, nextScheduledTime);
    } catch (e) {
      print('Failed to schedule task reminder: $e');
    }
  }

  tz.TZDateTime _calculateNextScheduledTime(Task task) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledTime;

    if (task.frequency == TaskFrequency.daily) {
      // Daily: Schedule for today or tomorrow
      scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        task.scheduledHour,
        task.scheduledMinute,
      );

      // If time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    } else if (task.frequency == TaskFrequency.monthly) {
      // Monthly: Schedule for this month or next month
      final dayOfMonth = task.dayOfMonth ?? 1;

      scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        dayOfMonth,
        task.scheduledHour,
        task.scheduledMinute,
      );

      // If time has passed this month, schedule for next month
      if (scheduledTime.isBefore(now)) {
        scheduledTime = tz.TZDateTime(
          tz.local,
          now.year,
          now.month + 1,
          dayOfMonth,
          task.scheduledHour,
          task.scheduledMinute,
        );
      }
    } else {
      // Custom: default to daily behavior
      scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        task.scheduledHour,
        task.scheduledMinute,
      );

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
    }

    return scheduledTime;
  }

  Future<void> _scheduleMainNotification(Task task, tz.TZDateTime scheduledTime) async {
    final int taskId = int.parse(task.id ?? '0');

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminder_channel',
      '할 일 알림',
      channelDescription: '예정된 시간의 할 일 알림',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId,
      '할 일 알림',
      task.title,
      scheduledTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _scheduleReminderNotification(Task task, tz.TZDateTime mainScheduledTime) async {
    final int taskId = int.parse(task.id ?? '0');
    final int reminderIntervalMinutes = task.getReminderIntervalMinutes();

    // Schedule reminder X minutes before the main notification
    final reminderTime = mainScheduledTime.subtract(Duration(minutes: reminderIntervalMinutes));

    // Only schedule if reminder time is in the future
    final now = tz.TZDateTime.now(tz.local);
    if (reminderTime.isAfter(now)) {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'task_reminder_advance_channel',
        '할 일 사전 알림',
        channelDescription: '할 일 ${reminderIntervalMinutes}분 전 알림',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        taskId * 1000, // Different ID for advance reminder
        '할 일 사전 알림',
        '${task.title} (${reminderIntervalMinutes}분 후)',
        reminderTime,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!isSupported || !_initialized) {
      print('Notifications not supported or not initialized, skipping cancel');
      return;
    }

    try {
      final int id = int.parse(taskId);
      await flutterLocalNotificationsPlugin.cancel(id);
      await flutterLocalNotificationsPlugin.cancel(id * 1000);
    } catch (e) {
      print('Failed to cancel task reminder: $e');
    }
  }

  Future<void> showImmediateNotification(String title, String body) async {
    if (!isSupported || !_initialized) {
      print('Notifications not supported or not initialized, skipping show');
      return;
    }

    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'immediate_channel',
        '즉시 알림',
        channelDescription: '즉시 표시되는 알림',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch % 100000,
        title,
        body,
        platformDetails,
      );
    } catch (e) {
      print('Failed to show immediate notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!isSupported || !_initialized) {
      print('Notifications not supported or not initialized, skipping cancel all');
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      print('Failed to cancel all notifications: $e');
    }
  }
}
