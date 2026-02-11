import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../models/task_completion.dart';
import '../models/birthday.dart';
import '../services/lunar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.week: 'Week',
              },
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              eventLoader: (day) {
                final tasks = taskProvider.getTasksForDate(day);
                final birthdays = taskProvider.getBirthdaysForDate(day);
                return [...tasks, ...birthdays];
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, events) {
                  if (events.isEmpty) return null;

                  final hasTasks = events.any((e) => e is Task);
                  final hasBirthdays = events.any((e) => e is Birthday);

                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasTasks)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (hasBirthdays)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: const BoxDecoration(
                              color: Colors.pink,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              calendarStyle: const CalendarStyle(
                markersMaxCount: 3,
                markerDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                leftChevronVisible: true,
                rightChevronVisible: true,
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(fontSize: 12),
                weekendStyle: TextStyle(fontSize: 12),
              ),
            ),
            // Monthly stats bar
            _buildMonthlyStatsBar(taskProvider),
            const Divider(height: 1),
            Expanded(
              child: _buildEventList(taskProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyStatsBar(TaskProvider taskProvider) {
    final stats = taskProvider.getMonthlyStats(_focusedDay.year, _focusedDay.month);
    final rate = stats.overallCompletionRate;
    Color progressColor;

    if (rate >= 80) {
      progressColor = Colors.green;
    } else if (rate >= 60) {
      progressColor = Colors.blue;
    } else if (rate >= 40) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${stats.monthLabel} 달성률',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${rate.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList(TaskProvider taskProvider) {
    final selectedDay = _selectedDay ?? DateTime.now();
    final tasks = taskProvider.getTasksForDate(selectedDay);
    final birthdays = taskProvider.getBirthdaysForDate(selectedDay);

    final lunarDate = LunarService.instance.formatLunarDate(selectedDay);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(selectedDay),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          lunarDate,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty && birthdays.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '이 날짜에 예정된 일정이 없습니다',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ),
          ),
        if (tasks.isNotEmpty) ...[
          const Text(
            '할 일',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...tasks.map((task) => _buildTaskCard(context, task, taskProvider, selectedDay)),
          const SizedBox(height: 16),
        ],
        if (birthdays.isNotEmpty) ...[
          const Text(
            '생일',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...birthdays.map((birthday) => Card(
                child: ListTile(
                  leading: const Icon(Icons.cake, color: Colors.pink),
                  title: Text(birthday.name),
                  subtitle: Text(
                    birthday.isLunar ? '음력 생일' : '양력 생일',
                  ),
                  trailing: birthday.notes != null
                      ? IconButton(
                          icon: const Icon(Icons.note),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(birthday.name),
                                content: Text(birthday.notes!),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('확인'),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : null,
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, TaskProvider taskProvider, DateTime selectedDay) {
    // For daily tasks, check completion on the selected date
    final isCompleted = task.frequency == TaskFrequency.daily
        ? taskProvider.isDailyTaskCompletedOn(task.id!, selectedDay)
        : task.isCompleted;

    return Card(
      child: ListTile(
        onTap: () => _showTaskDetailDialog(context, task, selectedDay),
        leading: Checkbox(
          value: isCompleted,
          onChanged: (value) {
            taskProvider.toggleTaskCompletion(task);
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            color: isCompleted ? Colors.grey : Colors.blue[700],
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null)
              Text(task.description!),
            if (task.notes != null)
              Text(
                task.notes!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            Text(
              '${task.scheduledHour.toString().padLeft(2, '0')}:${task.scheduledMinute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.frequency == TaskFrequency.daily)
              Icon(Icons.today, color: Colors.blue[300]),
            if (task.frequency == TaskFrequency.monthly)
              Icon(Icons.calendar_month, color: Colors.blue[300]),
            if (task.notes != null)
              Icon(Icons.note, color: Colors.blue[300]),
          ],
        ),
      ),
    );
  }

  void _showTaskDetailDialog(BuildContext context, Task task, DateTime selectedDay) {
    final taskProvider = context.read<TaskProvider>();
    final isDaily = task.frequency == TaskFrequency.daily;
    final isCompleted = isDaily
        ? taskProvider.isDailyTaskCompletedOn(task.id!, selectedDay)
        : task.isCompleted;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(task.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.description != null) ...[
                const Text('설명', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(task.description!),
                const SizedBox(height: 12),
              ],
              if (task.notes != null) ...[
                const Text('메모', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(task.notes!),
                const SizedBox(height: 12),
              ],
              Text('알림 시간: ${task.scheduledHour.toString().padLeft(2, '0')}:${task.scheduledMinute.toString().padLeft(2, '0')}'),
              Text('알림 간격: ${task.getReminderIntervalText()} 전'),
              const SizedBox(height: 12),
              Text('반복: ${isDaily ? '매일' : '매월 ${task.dayOfMonth}일'}'),
              if (isDaily) ...[
                const SizedBox(height: 8),
                Text(
                  '매일 반복되는 할 일입니다. 각 날짜별로 완료 여부를 기록합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () {
              taskProvider.toggleTaskCompletion(task);
              Navigator.pop(dialogContext);
            },
            style: FilledButton.styleFrom(
              backgroundColor: isCompleted ? Colors.orange : Colors.green,
            ),
            child: Text(isCompleted ? '완료 취소' : '완료'),
          ),
        ],
      ),
    );
  }
}
