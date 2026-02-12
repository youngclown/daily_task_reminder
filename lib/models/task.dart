enum TaskFrequency {
  daily,
  monthly,
  custom,
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
  final int scheduledHour; // Hour (0-23)
  final int scheduledMinute; // Minute (0-59)
  final bool adjustForHolidays;
  final bool isLunar;
  final ReminderInterval reminderInterval;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? notes;
  final String? linkedAppUrl;

  Task({
    this.id,
    required this.title,
    this.description,
    required this.frequency,
    this.dayOfMonth,
    this.scheduledHour = 9, // Default 9 AM
    this.scheduledMinute = 0, // Default 0 minutes
    this.adjustForHolidays = false,
    this.isLunar = false,
    this.reminderInterval = ReminderInterval.minutes30,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
    this.dueDate,
    this.notes,
    this.linkedAppUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'frequency': frequency.index,
      'dayOfMonth': dayOfMonth,
      'scheduledHour': scheduledHour,
      'scheduledMinute': scheduledMinute,
      'adjustForHolidays': adjustForHolidays ? 1 : 0,
      'isLunar': isLunar ? 1 : 0,
      'reminderInterval': reminderInterval.index,
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'notes': notes,
      'linkedAppUrl': linkedAppUrl,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id']?.toString(),
      title: map['title'],
      description: map['description'],
      frequency: TaskFrequency.values[map['frequency']],
      dayOfMonth: map['dayOfMonth'],
      scheduledHour: map['scheduledHour'] ?? 9,
      scheduledMinute: map['scheduledMinute'] ?? 0,
      adjustForHolidays: map['adjustForHolidays'] == 1,
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
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskFrequency? frequency,
    int? dayOfMonth,
    int? scheduledHour,
    int? scheduledMinute,
    bool? adjustForHolidays,
    bool? isLunar,
    ReminderInterval? reminderInterval,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? dueDate,
    String? notes,
    String? linkedAppUrl,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      scheduledHour: scheduledHour ?? this.scheduledHour,
      scheduledMinute: scheduledMinute ?? this.scheduledMinute,
      adjustForHolidays: adjustForHolidays ?? this.adjustForHolidays,
      isLunar: isLunar ?? this.isLunar,
      reminderInterval: reminderInterval ?? this.reminderInterval,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      notes: notes ?? this.notes,
      linkedAppUrl: linkedAppUrl ?? this.linkedAppUrl,
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
