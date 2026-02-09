import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
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
                // Return combined list for marker display
                return [...tasks, ...birthdays];
              },
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
            const Divider(height: 1),
            Expanded(
              child: _buildEventList(taskProvider),
            ),
          ],
        );
      },
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
          ...tasks.map((task) => Card(
                child: ListTile(
                  leading: Icon(
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.isCompleted ? Colors.green : null,
                  ),
                  title: Text(task.title),
                  subtitle: task.description != null
                      ? Text(task.description!)
                      : null,
                  trailing: task.frequency == TaskFrequency.monthly
                      ? Icon(
                          Icons.calendar_month,
                          color: Colors.blue[300],
                        )
                      : null,
                ),
              )),
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
}
