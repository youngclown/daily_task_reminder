class TaskCompletion {
  final String taskId;
  final DateTime date;

  TaskCompletion({
    required this.taskId,
    required this.date,
  });

  // Get date as UTC midnight for consistent comparison
  static DateTime getDateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'date': getDateOnly(date).toIso8601String(),
    };
  }

  factory TaskCompletion.fromMap(Map<String, dynamic> map) {
    return TaskCompletion(
      taskId: map['taskId'],
      date: DateTime.parse(map['date']),
    );
  }
}
