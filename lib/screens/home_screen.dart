import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_item.dart';
import '../services/notification_service.dart';
import 'add_task_screen.dart';
import 'calendar_screen.dart';
import 'birthday_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final provider = context.read<TaskProvider>();
      await provider.loadTasks();
      await provider.loadBirthdays();

      // Reschedule notifications for all incomplete tasks
      for (final task in provider.tasks) {
        if (!task.isCompleted) {
          await NotificationService.instance.scheduleTaskReminder(task);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const TaskListTab(),
      const CalendarScreen(),
      const BirthdayScreen(),
      const StatisticsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('할 일 관리'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: '할 일',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: '캘린더',
          ),
          NavigationDestination(
            icon: Icon(Icons.cake),
            label: '생일',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: '통계',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTaskScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class TaskListTab extends StatelessWidget {
  const TaskListTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeTasks = taskProvider.activeTasks;
        final completedTasks = taskProvider.completedTasks;

        if (activeTasks.isEmpty && completedTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.task_alt,
                  size: 100,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  '등록된 할 일이 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '+ 버튼을 눌러 새 할 일을 추가하세요',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (activeTasks.isNotEmpty) ...[
              const Text(
                '진행 중',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...activeTasks.map((task) => TaskItem(task: task)),
              const SizedBox(height: 24),
            ],
            if (completedTasks.isNotEmpty) ...[
              const Text(
                '완료됨',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...completedTasks.map((task) => TaskItem(task: task)),
            ],
          ],
        );
      },
    );
  }

}
