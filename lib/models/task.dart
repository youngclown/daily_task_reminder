import 'package:flutter/material.dart';

// 할 일 색상 팔레트
const List<Color> taskColorPalette = [
  Color(0xFF2196F3), // 파랑
  Color(0xFFF44336), // 빨강
  Color(0xFF4CAF50), // 초록
  Color(0xFFFF9800), // 주황
  Color(0xFF9C27B0), // 보라
  Color(0xFF009688), // 청록
  Color(0xFFE91E63), // 분홍
  Color(0xFF795548), // 갈색
];

enum TaskFrequency {
  daily,   // 매일 반복 (지속형)
  monthly, // 매월 반복 (지속형)
  once,    // 일회성 (완료 시 영구 제거)
  weekly,  // 매주 반복 (지속형)
}

enum DailySchedule {
  all,          // 전체 (모든 요일)
  weekdaysOnly, // 주말(공휴일) 제외 - 평일만
  weekendsOnly, // 주말(공휴일) 만
}

enum ReminderInterval {
  minutes10,
  minutes30,
  hour1,
}

class Task {
  final String? id;
  final String title;
  final String? description;
  final TaskFrequency frequency;
  final int? dayOfMonth; // For monthly tasks
  final int? dayOfWeek;  // For weekly tasks (1=월, 2=화, ..., 7=일)
  final int scheduledHour; // Hour (0-23)
  final int scheduledMinute; // Minute (0-59)
  final bool adjustForHolidays;
  final bool holidayAdjustToNext; // true=다음 평일(월요일), false=이전 평일(금요일)
  final bool isLunar;
  final ReminderInterval reminderInterval;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? notes;
  final String? linkedAppUrl;
  final int? color; // Color.value (null이면 기본 파란색)
  final DailySchedule dailySchedule; // 매일 할 일의 요일 필터

  Color get taskColor => color != null ? Color(color!) : const Color(0xFF2196F3);

  Task({
    this.id,
    required this.title,
    this.description,
    required this.frequency,
    this.dayOfMonth,
    this.dayOfWeek,
    this.scheduledHour = 9, // Default 9 AM
    this.scheduledMinute = 0, // Default 0 minutes
    this.adjustForHolidays = false,
    this.holidayAdjustToNext = true,
    this.isLunar = false,
    this.reminderInterval = ReminderInterval.minutes30,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    this.dueDate,
    this.notes,
    this.linkedAppUrl,
    this.color,
    this.dailySchedule = DailySchedule.all,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'frequency': frequency.index,
      'dayOfMonth': dayOfMonth,
      'dayOfWeek': dayOfWeek,
      'scheduledHour': scheduledHour,
      'scheduledMinute': scheduledMinute,
      'adjustForHolidays': adjustForHolidays ? 1 : 0,
      'holidayAdjustToNext': holidayAdjustToNext ? 1 : 0,
      'isLunar': isLunar ? 1 : 0,
      'reminderInterval': reminderInterval.index,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'notes': notes,
      'linkedAppUrl': linkedAppUrl,
      'color': color,
      'dailySchedule': dailySchedule.index,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id']?.toString(),
      title: map['title'],
      description: map['description'],
      frequency: TaskFrequency.values[map['frequency']],
      dayOfMonth: map['dayOfMonth'],
      dayOfWeek: map['dayOfWeek'],
      scheduledHour: map['scheduledHour'] ?? 9,
      scheduledMinute: map['scheduledMinute'] ?? 0,
      adjustForHolidays: map['adjustForHolidays'] == 1,
      holidayAdjustToNext: map['holidayAdjustToNext'] != 0,
      isLunar: map['isLunar'] == 1,
      reminderInterval: ReminderInterval.values[map['reminderInterval']],
      isCompleted: map['isCompleted'] == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      createdAt: DateTime.parse(map['createdAt']),
      dueDate:
          map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      notes: map['notes'],
      linkedAppUrl: map['linkedAppUrl'],
      color: map['color'],
      dailySchedule: DailySchedule.values[map['dailySchedule'] ?? 0],
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskFrequency? frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    int? scheduledHour,
    int? scheduledMinute,
    bool? adjustForHolidays,
    bool? holidayAdjustToNext,
    bool? isLunar,
    ReminderInterval? reminderInterval,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? dueDate,
    String? notes,
    String? linkedAppUrl,
    int? color,
    DailySchedule? dailySchedule,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      scheduledHour: scheduledHour ?? this.scheduledHour,
      scheduledMinute: scheduledMinute ?? this.scheduledMinute,
      adjustForHolidays: adjustForHolidays ?? this.adjustForHolidays,
      holidayAdjustToNext: holidayAdjustToNext ?? this.holidayAdjustToNext,
      isLunar: isLunar ?? this.isLunar,
      reminderInterval: reminderInterval ?? this.reminderInterval,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      linkedAppUrl: linkedAppUrl ?? this.linkedAppUrl,
      color: color ?? this.color,
      dailySchedule: dailySchedule ?? this.dailySchedule,
    );
  }

  String getReminderIntervalText() {
    switch (reminderInterval) {
      case ReminderInterval.minutes10:
        return '10분';
      case ReminderInterval.minutes30:
        return '30분';
      case ReminderInterval.hour1:
        return '1시간';
    }
  }

  int getReminderIntervalMinutes() {
    switch (reminderInterval) {
      case ReminderInterval.minutes10:
        return 10;
      case ReminderInterval.minutes30:
        return 30;
      case ReminderInterval.hour1:
        return 60;
    }
  }
}
