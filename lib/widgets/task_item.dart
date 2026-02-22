import 'package:flutter/material.dart';
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

    final isCompleted = taskProvider.isTaskCompletedOnDate(task, DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isCompleted ? 0 : 2,
        color: isCompleted ? Colors.grey[100] : null,
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 좌측 색상 바
              Container(
                width: 5,
                color: isCompleted ? Colors.grey[400] : task.taskColor,
              ),
              Expanded(
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
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
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
                                : task.frequency == TaskFrequency.weekly
                                    ? Icons.view_week_outlined
                                    : Icons.calendar_month,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getFrequencyText(),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${task.scheduledHour.toString().padLeft(2, '0')}:${task.scheduledMinute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.notifications, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            task.getReminderIntervalText(),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      // once 완료일시만 표시, 반복형은 텍스트 없이 체크박스로만 표시
                      if (task.frequency == TaskFrequency.once && task.completedAt != null)
                        Text(
                          '완료: ${DateFormat('M월 d일 HH:mm').format(task.completedAt!)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (task.linkedAppUrl != null && task.linkedAppUrl!.isNotEmpty)
                        Icon(Icons.link, color: Colors.blue[400], size: 18),
                      if (task.isLunar)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.nightlight_round, color: Colors.orange[300], size: 18),
                        ),
                      // 수정/삭제 메뉴 버튼
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddTaskScreen(task: task),
                              ),
                            );
                          } else if (value == 'delete') {
                            _confirmDelete(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('수정'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('삭제', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFrequencyText() {
    switch (task.frequency) {
      case TaskFrequency.daily:
        switch (task.dailySchedule) {
          case DailySchedule.all:
            return '매일';
          case DailySchedule.weekdaysOnly:
            return '매일 (주말 제외)';
          case DailySchedule.weekendsOnly:
            return '매일 (주말만)';
        }
      case TaskFrequency.weekly:
        const dayNames = ['', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
        final day = task.dayOfWeek ?? 1;
        return '매주 ${dayNames[day]}';
      case TaskFrequency.monthly:
        if (task.adjustForHolidays) {
          final dir = task.holidayAdjustToNext ? '월요일로 미루기' : '금요일로 당기기';
          return '매월 ${task.dayOfMonth}일 ($dir)';
        }
        return '매월 ${task.dayOfMonth}일';
      case TaskFrequency.once:
        return '일회성';
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('할 일 삭제'),
        content: Text('"${task.title}"\n\n정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<TaskProvider>().deleteTask(task.id!);
              Navigator.pop(dialogContext);
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
