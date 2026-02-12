import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/birthday.dart';
import '../services/lunar_service.dart';

class BirthdayScreen extends StatelessWidget {
  const BirthdayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<TaskProvider>(
        builder: (context, taskProvider, child) {
          if (taskProvider.birthdays.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cake,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 생일이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: taskProvider.birthdays.length,
            itemBuilder: (context, index) {
              final birthday = taskProvider.birthdays[index];
              final now = DateTime.now();

              // Calculate this year's birthday
              DateTime displayDate;
              if (birthday.isLunar) {
                displayDate = LunarService.instance.getLunarBirthdayThisYear(birthday.date, now.year);
              } else {
                displayDate = DateTime(now.year, birthday.date.month, birthday.date.day);
              }

              // If this year's birthday has passed, use next year's birthday
              if (displayDate.isBefore(DateTime(now.year, now.month, now.day))) {
                if (birthday.isLunar) {
                  displayDate = LunarService.instance.getLunarBirthdayThisYear(birthday.date, now.year + 1);
                } else {
                  displayDate = DateTime(now.year + 1, birthday.date.month, birthday.date.day);
                }
              }

              final daysUntil = displayDate.difference(DateTime(now.year, now.month, now.day)).inDays;
              final age = now.year - birthday.date.year;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.pink[100],
                    child: const Icon(Icons.cake, color: Colors.pink),
                  ),
                  title: Text(birthday.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('M월 d일').format(displayDate)} ${birthday.isLunar ? '(음력)' : '(양력)'}',
                      ),
                      if (daysUntil >= 0)
                        Text(
                          daysUntil == 0
                              ? '오늘이 생일입니다! 🎉'
                              : 'D-$daysUntil · 만 $age세',
                          style: TextStyle(
                            color: daysUntil == 0 ? Colors.red : Colors.blue,
                            fontWeight: daysUntil == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
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
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddEditDialog(context, birthday: birthday);
                      } else if (value == 'delete') {
                        _deleteBirthday(context, birthday);
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {Birthday? birthday}) {
    final nameController = TextEditingController(text: birthday?.name ?? '');
    final notesController = TextEditingController(text: birthday?.notes ?? '');
    DateTime selectedDate = birthday?.date ?? DateTime.now();
    bool isLunar = birthday?.isLunar ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(birthday == null ? '생일 추가' : '생일 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormat('yyyy년 M월 d일').format(selectedDate),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        selectedDate = date;
                      });
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('음력 생일'),
                  value: isLunar,
                  onChanged: (value) {
                    setState(() {
                      isLunar = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택사항)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  // Convert lunar date to solar date if needed
                  DateTime finalDate = selectedDate;
                  if (isLunar) {
                    try {
                      // User selected date is interpreted as lunar date
                      // Convert it to solar date for storage
                      final solar = LunarService.instance.lunarToSolar(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                      );
                      finalDate = DateTime(
                        solar.getYear(),
                        solar.getMonth(),
                        solar.getDay(),
                      );
                    } catch (e) {
                      // If conversion fails, use original date
                      finalDate = selectedDate;
                    }
                  }

                  final newBirthday = Birthday(
                    id: birthday?.id,
                    name: nameController.text,
                    date: finalDate,
                    isLunar: isLunar,
                    notes: notesController.text.isEmpty
                        ? null
                        : notesController.text,
                    createdAt: birthday?.createdAt,
                  );

                  final taskProvider =
                      Provider.of<TaskProvider>(dialogContext, listen: false);
                  if (birthday == null) {
                    taskProvider.addBirthday(newBirthday);
                  } else {
                    taskProvider.updateBirthday(newBirthday);
                  }

                  Navigator.pop(context);
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        birthday == null ? '생일이 추가되었습니다' : '생일이 수정되었습니다',
                      ),
                    ),
                  );
                }
              },
              child: Text(birthday == null ? '추가' : '수정'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteBirthday(BuildContext context, Birthday birthday) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('생일 삭제'),
        content: Text('${birthday.name}의 생일을 삭제하시겠습니까?'),
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
              Provider.of<TaskProvider>(dialogContext, listen: false)
                  .deleteBirthday(birthday.id!);
              Navigator.pop(context);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('생일이 삭제되었습니다')),
              );
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
