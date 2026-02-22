import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
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

    // Android 12+에서 정확한 알람 권한 요청 (설정 화면으로 이동)
    await androidImplementation?.requestExactAlarmsPermission();

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    await iosImplementation?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 삼성 등 배터리 최적화가 알람을 죽이는 것을 방지
    if (Platform.isAndroid) {
      final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
      if (!batteryStatus.isGranted) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  Future<void> scheduleTaskReminder(Task task) async {
    if (!isSupported || !_initialized) {
      print('[NOTIFICATION] Notifications not supported or not initialized, skipping schedule');
      return;
    }
    if (task.isCompleted) return;

    try {
      // Debug: Print scheduling information
      print('[NOTIFICATION] ==================== Scheduling Task ====================');
      print('[NOTIFICATION] Task: ${task.title}');
      print('[NOTIFICATION] Target time: ${task.scheduledHour.toString().padLeft(2, '0')}:${task.scheduledMinute.toString().padLeft(2, '0')}');
      print('[NOTIFICATION] Frequency: ${task.frequency}');
      print('[NOTIFICATION] Day of month: ${task.dayOfMonth}');
      print('[NOTIFICATION] Current time: ${tz.TZDateTime.now(tz.local)}');
      print('[NOTIFICATION] Local timezone: ${tz.local.name}');

      // 1. Cancel existing notifications
      await cancelTaskReminder(task.id!);

      // 2. Calculate next scheduled time
      final nextScheduledTime = _calculateNextScheduledTime(task);
      print('[NOTIFICATION] Scheduled at: $nextScheduledTime');

      // 3. Schedule main notification
      await _scheduleMainNotification(task, nextScheduledTime);

      // 4. Schedule reminder notification (X minutes before)
      await _scheduleReminderNotification(task, nextScheduledTime);
      print('[NOTIFICATION] ========================================================');
    } catch (e) {
      print('[NOTIFICATION] Failed to schedule task reminder: $e');
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
    } else if (task.frequency == TaskFrequency.weekly) {
      // Weekly: 지정된 요일의 다음 발생 시간 계산 (1=월 ~ 7=일)
      final targetDayOfWeek = task.dayOfWeek ?? DateTime.monday;

      scheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        task.scheduledHour,
        task.scheduledMinute,
      );

      int daysUntilTarget = (targetDayOfWeek - now.weekday + 7) % 7;
      // 오늘이 대상 요일이지만 시간이 이미 지난 경우 → 다음 주
      if (daysUntilTarget == 0 && scheduledTime.isBefore(now)) {
        daysUntilTarget = 7;
      }
      scheduledTime = scheduledTime.add(Duration(days: daysUntilTarget));
    } else {
      // once: 오늘 시간 기준
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

  Future<AndroidScheduleMode> _getScheduleMode() async {
    if (Platform.isAndroid) {
      final androidImpl = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidImpl?.canScheduleExactNotifications() ?? false;
      print('[NOTIFICATION] Exact alarm permitted: $canExact');
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  Future<void> _scheduleMainNotification(Task task, tz.TZDateTime scheduledTime) async {
    final int taskId = int.parse(task.id ?? '0');

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminder_channel_v3',
      '할 일 알림',
      channelDescription: '예정된 시간의 할 일 알림',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 반복 주기에 맞게 matchDateTimeComponents 설정
    DateTimeComponents? repeatComponents;
    if (task.frequency == TaskFrequency.daily) {
      repeatComponents = DateTimeComponents.time; // 매일 같은 시간 반복
    } else if (task.frequency == TaskFrequency.monthly) {
      repeatComponents = DateTimeComponents.dayOfMonthAndTime; // 매월 같은 날/시간 반복
    } else if (task.frequency == TaskFrequency.weekly) {
      repeatComponents = DateTimeComponents.dayOfWeekAndTime; // 매주 같은 요일/시간 반복
    }

    final scheduleMode = await _getScheduleMode();

    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId,
      '할 일 알림',
      task.title,
      scheduledTime,
      platformDetails,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatComponents,
    );
    print('[NOTIFICATION] Main notification scheduled (mode: $scheduleMode)');
  }

  Future<void> _scheduleReminderNotification(Task task, tz.TZDateTime mainScheduledTime) async {
    final int taskId = int.parse(task.id ?? '0');
    final int reminderIntervalMinutes = task.getReminderIntervalMinutes();

    // 사전 알림 시간 = 메인 알림 시간 - N분
    tz.TZDateTime reminderTime = mainScheduledTime.subtract(Duration(minutes: reminderIntervalMinutes));

    final now = tz.TZDateTime.now(tz.local);

    // 사전 알림 시간이 과거면 다음 발생 시점으로 조정
    if (reminderTime.isBefore(now)) {
      if (task.frequency == TaskFrequency.daily) {
        reminderTime = reminderTime.add(const Duration(days: 1));
      } else if (task.frequency == TaskFrequency.weekly) {
        reminderTime = reminderTime.add(const Duration(days: 7));
      } else if (task.frequency == TaskFrequency.monthly) {
        final nextMonth = reminderTime.month == 12 ? 1 : reminderTime.month + 1;
        final nextYear = reminderTime.month == 12 ? reminderTime.year + 1 : reminderTime.year;
        reminderTime = tz.TZDateTime(tz.local, nextYear, nextMonth, reminderTime.day, reminderTime.hour, reminderTime.minute);
      } else {
        // once: 과거면 사전 알림 스킵
        print('[NOTIFICATION] Reminder time is in the past for once task, skipping advance reminder');
        return;
      }
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminder_advance_channel_v3',
      '할 일 사전 알림',
      channelDescription: '할 일 ${reminderIntervalMinutes}분 전 알림',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    DateTimeComponents? repeatComponents;
    if (task.frequency == TaskFrequency.daily) {
      repeatComponents = DateTimeComponents.time;
    } else if (task.frequency == TaskFrequency.monthly) {
      repeatComponents = DateTimeComponents.dayOfMonthAndTime;
    } else if (task.frequency == TaskFrequency.weekly) {
      repeatComponents = DateTimeComponents.dayOfWeekAndTime;
    }

    final scheduleMode = await _getScheduleMode();

    await flutterLocalNotificationsPlugin.zonedSchedule(
      taskId * 1000,
      '할 일 사전 알림',
      '${task.title} (${reminderIntervalMinutes}분 후)',
      reminderTime,
      platformDetails,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: repeatComponents,
    );
    print('[NOTIFICATION] Advance reminder scheduled at: $reminderTime');
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
