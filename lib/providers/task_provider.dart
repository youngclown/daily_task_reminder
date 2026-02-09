import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/birthday.dart';
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

  List<Task> get activeTasks =>
      _tasks.where((task) => !task.isCompleted).toList();
  List<Task> get completedTasks =>
      _tasks.where((task) => task.isCompleted).toList();

  Future<void> loadTasks() async {
    _isLoading = true;
    notifyListeners();

    _tasks = await DatabaseService.instance.readAllTasks();

    _isLoading = false;
    notifyListeners();
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

      // Update notification
      if (task.isCompleted) {
        await NotificationService.instance.cancelTaskReminder(task.id!);
      } else {
        await NotificationService.instance.scheduleTaskReminder(task);
      }

      notifyListeners();
    }
  }

  Future<void> toggleTaskCompletion(Task task) async {
    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    await updateTask(updatedTask);
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
      if (task.isCompleted) return false;

      if (task.frequency == TaskFrequency.daily) {
        return true;
      } else if (task.frequency == TaskFrequency.monthly) {
        return date.day == task.dayOfMonth;
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
}
