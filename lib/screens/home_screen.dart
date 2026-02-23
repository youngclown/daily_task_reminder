import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
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

      // 권한 상태 확인 및 필요시 안내
      if (Platform.isAndroid) {
        await _checkAndRequestPermissions();
      }

      // Reschedule notifications for all incomplete tasks
      for (final task in provider.tasks) {
        if (!task.isCompleted) {
          await NotificationService.instance.scheduleTaskReminder(task);
        }
      }
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    final status = await NotificationService.instance.checkPermissionStatus();

    if (!status.allGranted && mounted) {
      _showPermissionDialog(status);
    }
  }

  void _showPermissionDialog(NotificationPermissionStatus status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('알림 권한 필요'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '정확한 시간에 알림을 받으려면 다음 권한이 필요합니다:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              '알림 권한',
              status.notificationGranted,
              '앱에서 알림을 표시할 수 있습니다',
            ),
            const SizedBox(height: 8),
            _buildPermissionItem(
              '정확한 알람 권한',
              status.exactAlarmGranted,
              '정확한 시간에 알림을 받을 수 있습니다',
            ),
            const SizedBox(height: 8),
            _buildPermissionItem(
              '배터리 최적화 제외',
              status.batteryOptimizationIgnored,
              '앱이 백그라운드에서 알림을 보낼 수 있습니다',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '삼성 기기는 추가로 "앱 절전" 설정에서 이 앱을 "제한 없음"으로 설정해주세요.',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestMissingPermissions(status);
            },
            child: const Text('권한 설정'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String title, bool granted, String description) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          color: granted ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: granted ? Colors.green : Colors.red,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _requestMissingPermissions(NotificationPermissionStatus status) async {
    final notificationService = NotificationService.instance;

    // 1. 알림 권한
    if (!status.notificationGranted) {
      await notificationService.requestNotificationPermission();
    }

    // 2. 정확한 알람 권한 (설정 화면으로 이동)
    if (!status.exactAlarmGranted) {
      if (mounted) {
        final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('정확한 알람 설정'),
            content: const Text(
              '정확한 시간에 알림을 받으려면 시스템 설정에서 "알람 및 리마인더" 권한을 허용해주세요.\n\n'
              '설정 화면으로 이동합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('설정으로 이동'),
              ),
            ],
          ),
        );

        if (shouldOpen == true) {
          await notificationService.openExactAlarmSettings();
        }
      }
    }

    // 3. 배터리 최적화 제외
    if (!status.batteryOptimizationIgnored) {
      await notificationService.requestBatteryOptimization();
    }

    // 권한 다시 확인
    if (mounted) {
      final newStatus = await notificationService.checkPermissionStatus();
      if (newStatus.allGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('모든 알림 권한이 설정되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (newStatus.missingPermissions.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('아직 설정되지 않은 권한: ${newStatus.missingPermissions.join(", ")}'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: '다시 설정',
              textColor: Colors.white,
              onPressed: () => _showPermissionDialog(newStatus),
            ),
          ),
        );
      }
    }
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
        actions: [
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: '알림 권한 설정',
              onPressed: () async {
                final status = await NotificationService.instance.checkPermissionStatus();
                if (mounted) {
                  if (status.allGranted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('모든 알림 권한이 설정되어 있습니다'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    _showPermissionDialog(status);
                  }
                }
              },
            ),
        ],
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
