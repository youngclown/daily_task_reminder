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
        final monthlyStats = taskProvider.currentMonthStats;

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
            // Monthly stats card
            _buildMonthlyStatsCard(context, monthlyStats),
            const SizedBox(height: 16),
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

  Widget _buildMonthlyStatsCard(BuildContext context, monthlyStats) {
    final rate = monthlyStats.overallCompletionRate;
    Color progressColor;
    String statusText;

    if (rate >= 80) {
      progressColor = Colors.green;
      statusText = '훌륭해요!';
    } else if (rate >= 60) {
      progressColor = Colors.blue;
      statusText = '잘하고 있어요';
    } else if (rate >= 40) {
      progressColor = Colors.orange;
      statusText = '조금만 더!';
    } else {
      progressColor = Colors.red;
      statusText = '화이팅!';
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${monthlyStats.monthLabel} 달성률',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${rate.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    color: progressColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${monthlyStats.currentDay}/${monthlyStats.totalDays}일',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
