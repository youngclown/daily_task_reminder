import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../screens/add_task_screen.dart';

class TaskItem extends StatelessWidget {
  final Task task;

  const TaskItem({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();

    // For daily tasks, check today's completion status from task_completions
    final isCompleted = task.frequency == TaskFrequency.daily
        ? taskProvider.isDailyTaskCompletedOn(task.id!, DateTime.now())
        : task.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (context) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTaskScreen(task: task),
                  ),
                );
              },
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: '수정',
            ),
            SlidableAction(
              onPressed: (context) {
                _deleteTask(context);
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: '삭제',
            ),
          ],
        ),
        child: Card(
          elevation: isCompleted ? 0 : 2,
          color: isCompleted ? Colors.grey[100] : null,
          child: ListTile(
            leading: Checkbox(
              value: isCompleted,
              onChanged: (value) {
                taskProvider.toggleTaskCompletion(task);
              },
            ),
            onTap: task.linkedAppUrl != null && task.linkedAppUrl!.isNotEmpty
                ? () => _launchLinkedApp(context)
                : null,
            title: Text(
              task.title,
              style: TextStyle(
                decoration:
                    isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey[600] : Colors.blue[700],
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description != null)
                  Text(
                    task.description!,
                    style: TextStyle(
                      color: isCompleted ? Colors.grey : null,
                    ),
                  ),
                if (task.notes != null)
                  Text(
                    task.notes!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? Colors.grey[500] : Colors.blue[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      task.frequency == TaskFrequency.daily
                          ? Icons.today
                          : Icons.calendar_month,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getFrequencyText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task.scheduledHour.toString().padLeft(2, '0')}:${task.scheduledMinute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.notifications,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.getReminderIntervalText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                // Only show completedAt for non-daily tasks
                if (task.frequency != TaskFrequency.daily && task.completedAt != null)
                  Text(
                    '완료: ${DateFormat('M월 d일 HH:mm').format(task.completedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                // For daily tasks, show today's completion status
                if (task.frequency == TaskFrequency.daily && isCompleted)
                  Text(
                    '오늘 완료',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.linkedAppUrl != null && task.linkedAppUrl!.isNotEmpty)
                  Tooltip(
                    message: '연결된 앱 실행',
                    child: Icon(
                      Icons.link,
                      color: Colors.blue[400],
                      size: 20,
                    ),
                  ),
                if (task.isLunar) ...[
                  if (task.linkedAppUrl != null && task.linkedAppUrl!.isNotEmpty)
                    const SizedBox(width: 8),
                  Tooltip(
                    message: '음력 날짜',
                    child: Icon(
                      Icons.nightlight_round,
                      color: Colors.orange[300],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFrequencyText() {
    switch (task.frequency) {
      case TaskFrequency.daily:
        return '매일';
      case TaskFrequency.monthly:
        final lunar = task.isLunar ? '음력 ' : '';
        final adjust = task.adjustForHolidays ? ' (휴일조정)' : '';
        return '$lunar매월 ${task.dayOfMonth}일$adjust';
      case TaskFrequency.custom:
        return '사용자 지정';
    }
  }

  void _deleteTask(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('할 일 삭제'),
        content: const Text('이 할 일을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              context.read<TaskProvider>().deleteTask(task.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('할 일이 삭제되었습니다')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchLinkedApp(BuildContext context) async {
    final url = task.linkedAppUrl;
    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);
    final canLaunch = await canLaunchUrl(uri);

    if (canLaunch) {
      await launchUrl(uri);

      // Also toggle task completion
      if (context.mounted) {
        context.read<TaskProvider>().toggleTaskCompletion(task);
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URL을 열 수 없습니다: $url')),
        );
      }
    }
  }
}
