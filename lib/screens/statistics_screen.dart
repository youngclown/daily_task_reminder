import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth.month == 1) {
        _selectedMonth = DateTime(_selectedMonth.year - 1, 12);
      } else {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      }
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = _selectedMonth.month == 12
        ? DateTime(_selectedMonth.year + 1, 1)
        : DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    // Don't allow going beyond current month
    if (!nextMonth.isAfter(DateTime(now.year, now.month))) {
      setState(() {
        _selectedMonth = nextMonth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final stats = taskProvider.getMonthlyStats(
          _selectedMonth.year,
          _selectedMonth.month,
        );

        return Scaffold(
          body: Column(
            children: [
              _buildMonthSelector(stats),
              Expanded(
                child: _buildStatsContent(context, stats),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector(dynamic stats) {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          Column(
            children: [
              Text(
                stats.monthLabel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrentMonth)
                const Text(
                  '이번 달',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: isCurrentMonth ? null : _nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsContent(BuildContext context, dynamic stats) {
    if (stats.taskStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              '매일 반복 할 일이 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall stats card
        _buildOverallStatsCard(stats),
        const SizedBox(height: 20),
        // Individual task stats
        const Text(
          '할 일별 달성률',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...stats.taskStats.map((taskStat) => _buildTaskStatCard(taskStat)),
      ],
    );
  }

  Widget _buildOverallStatsCard(dynamic stats) {
    final rate = stats.overallCompletionRate;
    Color progressColor;
    String emoji;
    String message;

    if (rate >= 80) {
      progressColor = Colors.green;
      emoji = '🎉';
      message = '훌륭해요! 이대로 유지하세요!';
    } else if (rate >= 60) {
      progressColor = Colors.blue;
      emoji = '👍';
      message = '잘하고 있어요. 조금만 더!';
    } else if (rate >= 40) {
      progressColor = Colors.orange;
      emoji = '💪';
      message = '목표를 향해 힘내세요!';
    } else {
      progressColor = Colors.red;
      emoji = '🔥';
      message = '시작이 반입니다. 화이팅!';
    }

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              progressColor.withOpacity(0.1),
              progressColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${rate.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
                const Text(
                  '%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${stats.currentDay} / ${stats.totalDays}일',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskStatCard(taskStat) {
    final rate = taskStat.completionRate;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    taskStat.task.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
            if (taskStat.task.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  taskStat.task.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '완료: ${taskStat.completedDays}일',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '전체: ${taskStat.totalDays}일',
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
