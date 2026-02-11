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

  List<Task> get activeTasks {
    final today = _today;
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        // For daily tasks, check if completed today
        return !_isDailyTaskCompletedOn(task.id!, today);
      }
      return !task.isCompleted;
    }).toList();
  }

  List<Task> get completedTasks {
    final today = _today;
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        // For daily tasks, check if completed today
        return _isDailyTaskCompletedOn(task.id!, today);
      }
      return task.isCompleted;
    }).toList();
  }

  // Check if daily task is completed on specific date
  bool _isDailyTaskCompletedOn(String taskId, DateTime date) {
    return _dailyTaskCompletions
        .where((c) => c.taskId == taskId && c.date == date)
        .isNotEmpty;
  }

  // Cache for daily task completions
  final List<TaskCompletion> _dailyTaskCompletions = [];

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
    _dailyTaskCompletions.clear();
    _dailyTaskCompletions.addAll(
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

      // For daily tasks, always keep notification active
      // For monthly tasks, cancel notification when completed
      if (task.frequency == TaskFrequency.daily) {
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

  Future<void> toggleTaskCompletion(Task task) async {
    if (task.frequency == TaskFrequency.daily) {
      // For daily tasks, use task_completions table
      final today = _today;
      if (_isDailyTaskCompletedOn(task.id!, today)) {
        // Uncomplete: remove from task_completions
        await DatabaseService.instance.deleteTaskCompletion(task.id!, today);
        _dailyTaskCompletions.removeWhere(
          (c) => c.taskId == task.id! && c.date == today,
        );
      } else {
        // Complete: add to task_completions
        await DatabaseService.instance.createTaskCompletion(task.id!, today);
        _dailyTaskCompletions.add(
          TaskCompletion(taskId: task.id!, date: today),
        );
      }
      notifyListeners();
    } else {
      // For monthly tasks, use existing isCompleted field
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
    final targetDate = TaskCompletion.getDateOnly(date);
    return _tasks.where((task) {
      if (task.frequency == TaskFrequency.daily) {
        return true; // Always show daily tasks
      }

      // For monthly tasks, only show if not completed
      if (task.isCompleted) return false;

      if (task.frequency == TaskFrequency.monthly) {
        return date.day == task.dayOfMonth;
      }
      return false;
    }).toList();
  }

  // Check if a daily task is completed on a specific date
  bool isDailyTaskCompletedOn(String taskId, DateTime date) {
    return _isDailyTaskCompletedOn(taskId, TaskCompletion.getDateOnly(date));
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
