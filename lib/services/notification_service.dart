import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import 'dart:io' show Platform;
import '../models/task.dart';

/// 알림 권한 상태
class NotificationPermissionStatus {
  final bool notificationGranted;
  final bool exactAlarmGranted;
  final bool batteryOptimizationIgnored;

  NotificationPermissionStatus({
    required this.notificationGranted,
    required this.exactAlarmGranted,
    required this.batteryOptimizationIgnored,
  });

  bool get allGranted =>
      notificationGranted && exactAlarmGranted && batteryOptimizationIgnored;

  List<String> get missingPermissions {
    final missing = <String>[];
    if (!notificationGranted) missing.add('알림 권한');
    if (!exactAlarmGranted) missing.add('정확한 알람 권한');
    if (!batteryOptimizationIgnored) missing.add('배터리 최적화 제외');
    return missing;
  }
}

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

  /// 현재 알림 권한 상태 확인
  Future<NotificationPermissionStatus> checkPermissionStatus() async {
    if (!isSupported) {
      return NotificationPermissionStatus(
        notificationGranted: false,
        exactAlarmGranted: false,
        batteryOptimizationIgnored: false,
      );
    }

    bool notificationGranted = false;
    bool exactAlarmGranted = false;
    bool batteryOptimizationIgnored = false;

    if (Platform.isAndroid) {
      final androidImpl = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // 알림 권한 확인
      notificationGranted = await androidImpl?.areNotificationsEnabled() ?? false;

      // 정확한 알람 권한 확인
      exactAlarmGranted = await androidImpl?.canScheduleExactNotifications() ?? false;

      // 배터리 최적화 제외 확인
      batteryOptimizationIgnored = await Permission.ignoreBatteryOptimizations.isGranted;

      print('[NOTIFICATION] Permission Status:');
      print('[NOTIFICATION]   - Notification: $notificationGranted');
      print('[NOTIFICATION]   - Exact Alarm: $exactAlarmGranted');
      print('[NOTIFICATION]   - Battery Optimization Ignored: $batteryOptimizationIgnored');
    } else if (Platform.isIOS) {
      // iOS는 일반적으로 권한 요청 시 처리됨
      notificationGranted = true;
      exactAlarmGranted = true;
      batteryOptimizationIgnored = true;
    }

    return NotificationPermissionStatus(
      notificationGranted: notificationGranted,
      exactAlarmGranted: exactAlarmGranted,
      batteryOptimizationIgnored: batteryOptimizationIgnored,
    );
  }

  /// 알림 권한 요청 (결과 반환)
  Future<bool> requestNotificationPermission() async {
    if (!isSupported || !Platform.isAndroid) return true;

    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidImpl?.requestNotificationsPermission() ?? false;
    print('[NOTIFICATION] Notification permission granted: $granted');
    return granted;
  }

  /// 정확한 알람 권한 요청 (설정 화면으로 이동)
  Future<bool> requestExactAlarmPermission() async {
    if (!isSupported || !Platform.isAndroid) return true;

    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // 이미 권한이 있는지 확인
    final alreadyGranted = await androidImpl?.canScheduleExactNotifications() ?? false;
    if (alreadyGranted) {
      print('[NOTIFICATION] Exact alarm permission already granted');
      return true;
    }

    // 설정 화면으로 이동
    await androidImpl?.requestExactAlarmsPermission();

    // 설정에서 돌아온 후 다시 확인
    final granted = await androidImpl?.canScheduleExactNotifications() ?? false;
    print('[NOTIFICATION] Exact alarm permission after request: $granted');
    return granted;
  }

  /// 배터리 최적화 제외 요청
  Future<bool> requestBatteryOptimization() async {
    if (!isSupported || !Platform.isAndroid) return true;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      print('[NOTIFICATION] Battery optimization already ignored');
      return true;
    }

    final result = await Permission.ignoreBatteryOptimizations.request();
    print('[NOTIFICATION] Battery optimization ignore granted: ${result.isGranted}');
    return result.isGranted;
  }

  /// 모든 권한 요청 (기존 메서드 - 호환성 유지)
  Future<void> requestPermissions() async {
    if (!isSupported) {
      print('Notifications not supported on ${Platform.operatingSystem}, skipping permission request');
      return;
    }

    if (Platform.isAndroid) {
      await requestNotificationPermission();
      await requestExactAlarmPermission();
      await requestBatteryOptimization();
    } else if (Platform.isIOS) {
      final iosImpl = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

      await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  /// 정확한 알람 설정 화면 열기
  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;

    final androidImpl = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestExactAlarmsPermission();
  }

  /// 앱 알림 설정 화면 열기
  Future<void> openNotificationSettings() async {
    await Permission.notification.request();
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

      // 4. Schedule repeating reminders (every X minutes after main notification)
      await _scheduleRepeatingReminders(task, nextScheduledTime);
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

  /// 반복 알림 스케줄링 (N분마다 최대 6회 반복)
  Future<void> _scheduleRepeatingReminders(Task task, tz.TZDateTime mainScheduledTime) async {
    final int taskId = int.parse(task.id ?? '0');
    final int intervalMinutes = task.getReminderIntervalMinutes();
    const int maxRepeats = 6; // 최대 반복 횟수

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'task_reminder_repeat_channel',
      '할 일 반복 알림',
      channelDescription: '할 일 완료 전까지 ${intervalMinutes}분마다 반복 알림',
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

    final scheduleMode = await _getScheduleMode();

    // N분 간격으로 최대 maxRepeats회 반복 알림 스케줄링
    for (int i = 1; i <= maxRepeats; i++) {
      final reminderTime = mainScheduledTime.add(Duration(minutes: intervalMinutes * i));

      // 반복 알림 ID: taskId * 1000 + i (1~6)
      final notificationId = taskId * 1000 + i;

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '할 일 알림',
        '${task.title} (${intervalMinutes * i}분 경과)',
        reminderTime,
        platformDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      print('[NOTIFICATION] Repeat reminder #$i scheduled at: $reminderTime');
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!isSupported || !_initialized) {
      print('Notifications not supported or not initialized, skipping cancel');
      return;
    }

    try {
      final int id = int.parse(taskId);
      // 메인 알림 취소
      await flutterLocalNotificationsPlugin.cancel(id);
      // 반복 알림 취소 (최대 6개)
      for (int i = 1; i <= 6; i++) {
        await flutterLocalNotificationsPlugin.cancel(id * 1000 + i);
      }
      print('[NOTIFICATION] Cancelled all reminders for task $taskId');
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
