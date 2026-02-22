import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/birthday.dart';
import '../models/task_completion.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/lunar_service.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  List<Birthday> _birthdays = [];
  bool _isLoading = false;

  List<Task> get tasks => _tasks;
  List<Birthday> get birthdays => _birthdays;
  bool get isLoading => _isLoading;

  // Get today's date at midnight for consistent comparison
  DateTime get _today => TaskCompletion.getDateOnly(DateTime.now());

  // 매일 할 일의 요일 필터 충족 여부
  bool _isScheduledForDate(Task task, DateTime date) {
    if (task.frequency != TaskFrequency.daily) return true;
    switch (task.dailySchedule) {
      case DailySchedule.all:
        return true;
      case DailySchedule.weekdaysOnly:
        return date.weekday <= DateTime.friday; // 월~금
      case DailySchedule.weekendsOnly:
        return date.weekday >= DateTime.saturday; // 토~일
    }
  }

  List<Task> get activeTasks {
    final today = DateTime.now();
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        return _isScheduledForDate(task, today);
      }
      if (task.frequency == TaskFrequency.monthly) {
        return true;
      }
      if (task.frequency == TaskFrequency.weekly) {
        return task.dayOfWeek == today.weekday; // 오늘 요일인 경우만 표시
      }
      return !task.isCompleted; // once: 영구 완료되면 진행 중에서 제거
    }).toList();
  }

  List<Task> get completedTasks {
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily ||
          task.frequency == TaskFrequency.monthly ||
          task.frequency == TaskFrequency.weekly) {
        return false; // 반복형은 완료됨 목록에 표시 안 함
      }
      return task.isCompleted; // once만 완료됨으로 이동
    }).toList();
  }

  // Check if task is completed on specific date (daily: day key, monthly: month key)
  bool _isCompletedOn(String taskId, DateTime dateKey) {
    return _taskCompletions
        .where((c) => c.taskId == taskId && c.date == dateKey)
        .isNotEmpty;
  }

  // Legacy alias
  bool _isDailyTaskCompletedOn(String taskId, DateTime date) =>
      _isCompletedOn(taskId, date);

  // 매월 완료 키: 해당 월의 1일
  DateTime _monthKey(DateTime date) => DateTime(date.year, date.month, 1);

  // 매월 할 일이 특정 월에 완료됐는지 확인
  bool _isMonthlyCompletedFor(String taskId, DateTime date) =>
      _isCompletedOn(taskId, _monthKey(date));

  // Cache for all task completions (daily + monthly)
  final List<TaskCompletion> _taskCompletions = [];

  // Legacy getter for compatibility
  List<TaskCompletion> get _dailyTaskCompletions => _taskCompletions;

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    _tasks = await DatabaseService.instance.readAllTasks();

    // Load all daily task completions
    await _loadDailyTaskCompletions();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadDailyTaskCompletions() async {
    final db = await DatabaseService.instance.database;
    final result = await db.query('task_completions');
    _taskCompletions.clear();
    _taskCompletions.addAll(
      result.map((map) => TaskCompletion.fromMap(map)).toList(),
    );
  }

  Future<void> loadBirthdays() async {
    _isLoading = true;
    notifyListeners();

    _birthdays = await DatabaseService.instance.readAllBirthdays();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    final newTask = await DatabaseService.instance.createTask(task);
    _tasks.insert(0, newTask);

    // Schedule notification
    await NotificationService.instance.scheduleTaskReminder(newTask);

    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await DatabaseService.instance.updateTask(task);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = task;

      // 반복형(daily/weekly/monthly)은 항상 알림 유지, once는 완료 시 취소
      if (task.frequency == TaskFrequency.daily ||
          task.frequency == TaskFrequency.weekly ||
          task.frequency == TaskFrequency.monthly) {
        await NotificationService.instance.scheduleTaskReminder(task);
      } else {
        if (task.isCompleted) {
          await NotificationService.instance.cancelTaskReminder(task.id!);
        } else {
          await NotificationService.instance.scheduleTaskReminder(task);
        }
      }

      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(Task task, {DateTime? date}) async {
    final refDate = date ?? DateTime.now();

    if (task.frequency == TaskFrequency.daily ||
        task.frequency == TaskFrequency.weekly) {
      // 매일/매주: 날짜 단위로 완료 기록
      final dateKey = TaskCompletion.getDateOnly(refDate);
      if (_isCompletedOn(task.id!, dateKey)) {
        await DatabaseService.instance.deleteTaskCompletion(task.id!, dateKey);
        _taskCompletions.removeWhere(
          (c) => c.taskId == task.id! && c.date == dateKey,
        );
      } else {
        await DatabaseService.instance.createTaskCompletion(task.id!, dateKey);
        _taskCompletions.add(TaskCompletion(taskId: task.id!, date: dateKey));
      }
      notifyListeners();
    } else if (task.frequency == TaskFrequency.monthly) {
      // 매월: 월 단위로 완료 기록 (해당 월의 1일을 키로 사용)
      final monthKey = _monthKey(refDate);
      if (_isMonthlyCompletedFor(task.id!, refDate)) {
        await DatabaseService.instance.deleteTaskCompletion(task.id!, monthKey);
        _taskCompletions.removeWhere(
          (c) => c.taskId == task.id! && c.date == monthKey,
        );
      } else {
        await DatabaseService.instance.createTaskCompletion(task.id!, monthKey);
        _taskCompletions.add(TaskCompletion(taskId: task.id!, date: monthKey));
      }
      notifyListeners();
    } else {
      // once (일회성): 영구 완료
      final updatedTask = task.copyWith(
        isCompleted: !task.isCompleted,
        completedAt: !task.isCompleted ? DateTime.now() : null,
      );
      await updateTask(updatedTask);
    }
  }

  Future<void> deleteTask(String taskId) async {
    await DatabaseService.instance.deleteTask(taskId);
    await NotificationService.instance.cancelTaskReminder(taskId);
    _tasks.removeWhere((task) => task.id == taskId);
    notifyListeners();
  }

  Future<void> addBirthday(Birthday birthday) async {
    final newBirthday = await DatabaseService.instance.createBirthday(birthday);
    _birthdays.add(newBirthday);
    _birthdays.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();
  }

  Future<void> updateBirthday(Birthday birthday) async {
    await DatabaseService.instance.updateBirthday(birthday);
    final index = _birthdays.indexWhere((b) => b.id == birthday.id);
    if (index != -1) {
      _birthdays[index] = birthday;
      _birthdays.sort((a, b) => a.date.compareTo(b.date));
      notifyListeners();
    }
  }

  Future<void> deleteBirthday(String birthdayId) async {
    await DatabaseService.instance.deleteBirthday(birthdayId);
    _birthdays.removeWhere((birthday) => birthday.id == birthdayId);
    notifyListeners();
  }

  List<Task> getTasksForDate(DateTime date) {
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        return _isScheduledForDate(task, date);
      }
      if (task.frequency == TaskFrequency.weekly) {
        return task.dayOfWeek == date.weekday;
      }
      if (task.frequency == TaskFrequency.monthly) {
        return date.day == task.dayOfMonth;
      }
      // once: 완료 안 된 것만 표시
      return !task.isCompleted;
    }).toList();
  }

  // 매일 할 일이 특정 날짜에 완료됐는지 (public)
  bool isDailyTaskCompletedOn(String taskId, DateTime date) {
    return _isCompletedOn(taskId, TaskCompletion.getDateOnly(date));
  }

  // 매월 할 일이 특정 날짜의 해당 월에 완료됐는지 (public)
  bool isMonthlyTaskCompletedFor(String taskId, DateTime date) {
    return _isMonthlyCompletedFor(taskId, date);
  }

  // 할 일이 특정 날짜 기준으로 완료됐는지 통합 확인 (캘린더용)
  bool isTaskCompletedOnDate(Task task, DateTime date) {
    if (task.frequency == TaskFrequency.daily ||
        task.frequency == TaskFrequency.weekly) {
      return isDailyTaskCompletedOn(task.id!, date);
    }
    if (task.frequency == TaskFrequency.monthly) {
      return isMonthlyTaskCompletedFor(task.id!, date);
    }
    return task.isCompleted;
  }

  // 특정 날짜에 미완료된 할 일 목록 (캘린더 마커용)
  List<Task> getIncompleteTasksForDate(DateTime date) {
    final dateKey = TaskCompletion.getDateOnly(date);
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        if (!_isScheduledForDate(task, date)) return false;
        return !_isCompletedOn(task.id!, dateKey);
      }
      if (task.frequency == TaskFrequency.weekly) {
        return task.dayOfWeek == date.weekday &&
            !_isCompletedOn(task.id!, dateKey);
      }
      if (task.frequency == TaskFrequency.monthly) {
        return date.day == task.dayOfMonth &&
            !_isMonthlyCompletedFor(task.id!, date);
      }
      return false;
    }).toList();
  }

  List<Birthday> getBirthdaysForDate(DateTime date) {
    return _birthdays.where((birthday) {
      if (birthday.isLunar) {
        // For lunar birthdays, convert to solar date for the target year
        final solarBirthdayThisYear =
            LunarService.instance.getLunarBirthdayThisYear(birthday.date, date.year);
        return solarBirthdayThisYear.year == date.year &&
               solarBirthdayThisYear.month == date.month &&
               solarBirthdayThisYear.day == date.day;
      } else {
        // For solar birthdays, just compare month and day
        return birthday.date.month == date.month &&
               birthday.date.day == date.day;
      }
    }).toList();
  }

  List<Birthday> getBirthdaysForMonth(int year, int month) {
    return _birthdays.where((birthday) {
      if (birthday.isLunar) {
        // For lunar birthdays, convert to solar date for the target year
        try {
          final solarBirthdayThisYear =
              LunarService.instance.getLunarBirthdayThisYear(birthday.date, year);
          return solarBirthdayThisYear.year == year &&
                 solarBirthdayThisYear.month == month;
        } catch (e) {
          return false;
        }
      } else {
        // For solar birthdays, just compare month
        return birthday.date.month == month && birthday.date.year <= year;
      }
    }).toList();
  }

  // Monthly completion rate statistics
  MonthlyStats getMonthlyStats(int year, int month) {
    final dailyTasks = _tasks.where((t) => t.frequency == TaskFrequency.daily).toList();

    // Get first and last day of the month
    final firstDay = DateTime(year, month, 1);
    final lastDay = month < 12
        ? DateTime(year, month + 1, 0)
        : DateTime(year, 12, 31);

    // Count days from first day to today (or last day if past month)
    final today = _today;
    final endDate = today.isBefore(lastDay) && today.year == year && today.month == month
        ? today
        : lastDay;
    final totalDaysInPeriod = endDate.day;
    final currentDay = today.year == year && today.month == month ? today.day : endDate.day;

    Map<String, TaskMonthlyStats> taskStats = {};

    for (final task in dailyTasks) {
      int completedDays = 0;
      int totalDays = totalDaysInPeriod;

      // Count completions for this task in the month
      for (int day = 1; day <= currentDay; day++) {
        final checkDate = DateTime(year, month, day);
        final dateOnly = TaskCompletion.getDateOnly(checkDate);
        if (_isDailyTaskCompletedOn(task.id!, dateOnly)) {
          completedDays++;
        }
      }

      final rate = totalDays > 0 ? (completedDays / totalDays * 100) : 0.0;
      taskStats[task.id!] = TaskMonthlyStats(
        task: task,
        completedDays: completedDays,
        totalDays: totalDays,
        completionRate: rate,
      );
    }

    // Calculate overall stats
    int totalCompleted = 0;
    int totalPossible = dailyTasks.length * totalDaysInPeriod;
    for (final stat in taskStats.values) {
      totalCompleted += stat.completedDays;
    }

    final overallRate = totalPossible > 0 ? (totalCompleted / totalPossible * 100) : 0.0;

    return MonthlyStats(
      year: year,
      month: month,
      totalDays: totalDaysInPeriod,
      currentDay: currentDay,
      overallCompletionRate: overallRate,
      taskStats: taskStats.values.toList(),
    );
  }

  // Get stats for current month
  MonthlyStats get currentMonthStats {
    final now = DateTime.now();
    return getMonthlyStats(now.year, now.month);
  }
}

// Statistics models
class MonthlyStats {
  final int year;
  final int month;
  final int totalDays;
  final int currentDay;
  final double overallCompletionRate;
  final List<TaskMonthlyStats> taskStats;

  MonthlyStats({
    required this.year,
    required this.month,
    required this.totalDays,
    required this.currentDay,
    required this.overallCompletionRate,
    required this.taskStats,
  });

  String get monthLabel => '$year년 ${month}월';
}

class TaskMonthlyStats {
  final Task task;
  final int completedDays;
  final int totalDays;
  final double completionRate;

  TaskMonthlyStats({
    required this.task,
    required this.completedDays,
    required this.totalDays,
    required this.completionRate,
  });
}
