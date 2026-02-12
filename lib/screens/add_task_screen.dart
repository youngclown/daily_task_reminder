import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _notesController;
  late TextEditingController _linkedAppUrlController;
  late TaskFrequency _frequency;
  late int _dayOfMonth;
  late int _scheduledHour;
  late int _scheduledMinute;
  late bool _adjustForHolidays;
  late bool _isLunar;
  late ReminderInterval _reminderInterval;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _notesController =
        TextEditingController(text: widget.task?.notes ?? '');
    _linkedAppUrlController =
        TextEditingController(text: widget.task?.linkedAppUrl ?? '');
    _frequency = widget.task?.frequency ?? TaskFrequency.daily;
    _dayOfMonth = widget.task?.dayOfMonth ?? 1;
    _scheduledHour = widget.task?.scheduledHour ?? 9;
    _scheduledMinute = widget.task?.scheduledMinute ?? 0;
    _adjustForHolidays = widget.task?.adjustForHolidays ?? false;
    _isLunar = widget.task?.isLunar ?? false;
    _reminderInterval =
        widget.task?.reminderInterval ?? ReminderInterval.minutes30;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _linkedAppUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? '할 일 추가' : '할 일 수정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '제목을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '설명 (선택사항)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkedAppUrlController,
              decoration: InputDecoration(
                labelText: '연결된 앱/웹사이트 URL (선택사항)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _linkedAppUrlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _testUrl(),
                        tooltip: 'URL 테스트',
                      )
                    : null,
                helperText: 'https://, tel:, mailto:, 앱 스킴 등',
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!_isValidUrl(value)) {
                    return '올바른 URL 형식이 아닙니다';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '메모 (선택사항)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkedAppUrlController,
              decoration: InputDecoration(
                labelText: '연결된 앱/웹사이트 URL (선택사항)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _linkedAppUrlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _testUrl(),
                        tooltip: 'URL 테스트',
                      )
                    : null,
                helperText: 'https://, tel:, mailto:, 앱 스킴 등',
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!_isValidUrl(value)) {
                    return '올바른 URL 형식이 아닙니다';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              '반복 주기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskFrequency>(
              segments: const [
                ButtonSegment(
                  value: TaskFrequency.daily,
                  label: Text('매일'),
                  icon: Icon(Icons.today),
                ),
                ButtonSegment(
                  value: TaskFrequency.monthly,
                  label: Text('매월'),
                  icon: Icon(Icons.calendar_month),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (Set<TaskFrequency> newSelection) {
                setState(() {
                  _frequency = newSelection.first;
                });
              },
            ),
            if (_frequency == TaskFrequency.monthly) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('매월', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _dayOfMonth,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(31, (index) => index + 1)
                          .map((day) => DropdownMenuItem(
                                value: day,
                                child: Text('$day일'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _dayOfMonth = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('음력 사용'),
                subtitle: const Text('음력 날짜로 할 일 등록'),
                value: _isLunar,
                onChanged: (value) {
                  setState(() {
                    _isLunar = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('공휴일 조정'),
                subtitle: const Text('토요일/일요일이면 평일로 조정'),
                value: _adjustForHolidays,
                onChanged: (value) {
                  setState(() {
                    _adjustForHolidays = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '알림 시간',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('시간 선택'),
                subtitle: Text(
                  '${_scheduledHour.toString().padLeft(2, '0')}:${_scheduledMinute.toString().padLeft(2, '0')}'
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectTime,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '알림 간격',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReminderInterval>(
              segments: const [
                ButtonSegment(
                  value: ReminderInterval.minutes10,
                  label: Text('10분'),
                ),
                ButtonSegment(
                  value: ReminderInterval.minutes30,
                  label: Text('30분'),
                ),
                ButtonSegment(
                  value: ReminderInterval.hour1,
                  label: Text('1시간'),
                ),
              ],
              selected: {_reminderInterval},
              onSelectionChanged: (Set<ReminderInterval> newSelection) {
                setState(() {
                  _reminderInterval = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saveTask,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: Text(
                widget.task == null ? '추가' : '수정',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _scheduledHour, minute: _scheduledMinute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _scheduledHour = picked.hour;
        _scheduledMinute = picked.minute;
      });
    }
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final task = Task(
        id: widget.task?.id,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        frequency: _frequency,
        dayOfMonth: _frequency == TaskFrequency.monthly ? _dayOfMonth : null,
        scheduledHour: _scheduledHour,
        scheduledMinute: _scheduledMinute,
        adjustForHolidays: _adjustForHolidays,
        isLunar: _isLunar,
        reminderInterval: _reminderInterval,
        createdAt: widget.task?.createdAt,
        notes: _notesController.text.isEmpty
            ? null
            : _notesController.text,
        linkedAppUrl: _linkedAppUrlController.text.isEmpty
            ? null
            : _linkedAppUrlController.text,
      );

      final taskProvider = context.read<TaskProvider>();
      if (widget.task == null) {
        await taskProvider.addTask(task);
      } else {
        await taskProvider.updateTask(task);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.task == null ? '할 일이 추가되었습니다' : '할 일이 수정되었습니다'),
          ),
        );
      }
    }
  }

  bool _isValidUrl(String url) {
    if (url.isEmpty) return true;

    // Check for common URL schemes
    final validSchemes = [
      'http://',
      'https://',
      'tel:',
      'mailto:',
      'sms:',
      'file://',
    ];

    // Check if it starts with a valid scheme
    for (final scheme in validSchemes) {
      if (url.toLowerCase().startsWith(scheme)) {
        return true;
      }
    }

    // Check for custom app schemes (e.g., myapp://, kakaotalk://)
    if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(url)) {
      return true;
    }

    return false;
  }

  Future<void> _testUrl() async {
    final url = _linkedAppUrlController.text;
    if (url.isEmpty) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL을 열 수 없습니다')),
        );
      }
    }
  }
}
