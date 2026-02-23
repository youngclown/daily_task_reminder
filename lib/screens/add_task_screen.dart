import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
  late TextEditingController _notesController;
  late TextEditingController _linkedAppUrlController;
  late TaskFrequency _frequency;
  late int _dayOfMonth;
  late int _dayOfWeek; // 1=월, 2=화, ..., 7=일
  late int _scheduledHour;
  late int _scheduledMinute;
  late bool _adjustForHolidays;
  late bool _holidayAdjustToNext; // true=월요일, false=금요일
  late DailySchedule _dailySchedule;
  late ReminderInterval _reminderInterval;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    // description과 notes 통합: 기존 데이터는 description 또는 notes 중 있는 것 사용
    _notesController = TextEditingController(
      text: widget.task?.notes ?? widget.task?.description ?? '',
    );
    _linkedAppUrlController =
        TextEditingController(text: widget.task?.linkedAppUrl ?? '');
    _frequency = widget.task?.frequency ?? TaskFrequency.daily;
    _dayOfMonth = widget.task?.dayOfMonth ?? 1;
    _dayOfWeek = widget.task?.dayOfWeek ?? DateTime.monday;
    _scheduledHour = widget.task?.scheduledHour ?? 9;
    _scheduledMinute = widget.task?.scheduledMinute ?? 0;
    _adjustForHolidays = widget.task?.adjustForHolidays ?? false;
    _holidayAdjustToNext = widget.task?.holidayAdjustToNext ?? true;
    _dailySchedule = widget.task?.dailySchedule ?? DailySchedule.all;
    _reminderInterval =
        widget.task?.reminderInterval ?? ReminderInterval.minutes30;
    _selectedColor = widget.task?.taskColor ?? taskColorPalette[0];
  }

  @override
  void dispose() {
    _titleController.dispose();
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
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '메모 (선택사항)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                helperText: '할 일에 대한 설명이나 메모를 입력하세요',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkedAppUrlController,
              decoration: InputDecoration(
                labelText: '연결된 앱/사이트 (선택사항)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _linkedAppUrlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => _testUrl(),
                        tooltip: 'URL 테스트',
                      )
                    : null,
                helperText: 'https://, tel:, 앱 스킴(kakao://) 등',
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
                  value: TaskFrequency.weekly,
                  label: Text('매주'),
                  icon: Icon(Icons.view_week_outlined),
                ),
                ButtonSegment(
                  value: TaskFrequency.monthly,
                  label: Text('매월'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: TaskFrequency.once,
                  label: Text('일회성'),
                  icon: Icon(Icons.check_circle_outline),
                ),
              ],
              selected: {_frequency},
              onSelectionChanged: (Set<TaskFrequency> newSelection) {
                setState(() {
                  _frequency = newSelection.first;
                });
              },
            ),
            if (_frequency == TaskFrequency.daily) ...[
              const SizedBox(height: 16),
              const Text(
                '적용 요일',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              SegmentedButton<DailySchedule>(
                segments: const [
                  ButtonSegment(
                    value: DailySchedule.all,
                    label: Text('전체'),
                    icon: Icon(Icons.calendar_today),
                  ),
                  ButtonSegment(
                    value: DailySchedule.weekdaysOnly,
                    label: Text('주말 제외'),
                    icon: Icon(Icons.work_outline),
                  ),
                  ButtonSegment(
                    value: DailySchedule.weekendsOnly,
                    label: Text('주말만'),
                    icon: Icon(Icons.weekend_outlined),
                  ),
                ],
                selected: {_dailySchedule},
                onSelectionChanged: (val) {
                  setState(() => _dailySchedule = val.first);
                },
              ),
            ],
            if (_frequency == TaskFrequency.weekly) ...[
              const SizedBox(height: 16),
              const Text(
                '요일 선택',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              _buildDayOfWeekPicker(),
            ],
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
                title: const Text('주말 조정'),
                subtitle: const Text('토요일/일요일이면 평일로 자동 조정'),
                value: _adjustForHolidays,
                onChanged: (value) {
                  setState(() {
                    _adjustForHolidays = value;
                  });
                },
              ),
              if (_adjustForHolidays) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '조정 방향',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('금요일로 당기기'),
                            icon: Icon(Icons.arrow_back),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('월요일로 미루기'),
                            icon: Icon(Icons.arrow_forward),
                          ),
                        ],
                        selected: {_holidayAdjustToNext},
                        onSelectionChanged: (val) {
                          setState(() => _holidayAdjustToNext = val.first);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
            const SizedBox(height: 24),
            const Text(
              '색상',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // 4가지 기본 색상
                ...taskColorPalette.map((color) {
                  final isSelected = _selectedColor.toARGB32() == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }),
                // 커스텀 색상 선택 버튼
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey[400]!, width: 2),
                      gradient: const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                    child: !_isPresetColor()
                        ? Container(
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black, width: 3),
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 20),
                          )
                        : const Icon(Icons.colorize, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
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
              '반복 알림',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '완료하지 않으면 설정한 간격마다 다시 알림',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReminderInterval>(
              segments: const [
                ButtonSegment(
                  value: ReminderInterval.minutes10,
                  label: Text('10분마다'),
                ),
                ButtonSegment(
                  value: ReminderInterval.minutes30,
                  label: Text('30분마다'),
                ),
                ButtonSegment(
                  value: ReminderInterval.hour1,
                  label: Text('1시간마다'),
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

  Widget _buildDayOfWeekPicker() {
    const dayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayValue = index + 1; // 1=월 ~ 7=일
        final isSelected = _dayOfWeek == dayValue;
        final isWeekend = dayValue >= 6;
        return GestureDetector(
          onTap: () => setState(() => _dayOfWeek = dayValue),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[400]!,
              ),
            ),
            child: Center(
              child: Text(
                dayLabels[index],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isWeekend
                          ? Colors.red[400]
                          : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
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

  bool _isPresetColor() {
    return taskColorPalette.any((c) => c.toARGB32() == _selectedColor.toARGB32());
  }

  void _showColorPicker() {
    Color pickerColor = _selectedColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('색상 선택'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: false,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _selectedColor = pickerColor);
              Navigator.pop(context);
            },
            child: const Text('선택'),
          ),
        ],
      ),
    );
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final task = Task(
        id: widget.task?.id,
        title: _titleController.text,
        frequency: _frequency,
        dayOfMonth: _frequency == TaskFrequency.monthly ? _dayOfMonth : null,
        dayOfWeek: _frequency == TaskFrequency.weekly ? _dayOfWeek : null,
        scheduledHour: _scheduledHour,
        scheduledMinute: _scheduledMinute,
        adjustForHolidays: _adjustForHolidays,
        holidayAdjustToNext: _holidayAdjustToNext,
        reminderInterval: _reminderInterval,
        createdAt: widget.task?.createdAt,
        notes: _notesController.text.isEmpty
            ? null
            : _notesController.text,
        linkedAppUrl: _linkedAppUrlController.text.isEmpty
            ? null
            : _linkedAppUrlController.text,
        color: _selectedColor.toARGB32(),
        dailySchedule: _frequency == TaskFrequency.daily
            ? _dailySchedule
            : DailySchedule.all,
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
