import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/birthday.dart';
import '../models/task_completion.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('daily_tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN scheduledHour INTEGER NOT NULL DEFAULT 9');
      await db.execute('ALTER TABLE tasks ADD COLUMN scheduledMinute INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN notes TEXT');
    }
    if (oldVersion < 4) {
      // Create task_completions table
      await db.execute('''
        CREATE TABLE task_completions (
          taskId TEXT NOT NULL,
          date TEXT NOT NULL,
          PRIMARY KEY (taskId, date)
        )
      ''');
      // Reset daily tasks isCompleted status
      await db.execute('UPDATE tasks SET isCompleted = 0, completedAt = NULL WHERE frequency = 0');
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textTypeNullable,
        frequency $intType,
        dayOfMonth INTEGER,
        scheduledHour $intType DEFAULT 9,
        scheduledMinute $intType DEFAULT 0,
        adjustForHolidays $intType,
        isLunar $intType,
        reminderInterval $intType,
        isCompleted $intType,
        completedAt $textTypeNullable,
        createdAt $textType,
        dueDate $textTypeNullable,
        notes $textTypeNullable
      )
    ''');

    await db.execute('''
      CREATE TABLE birthdays (
        id $idType,
        name $textType,
        date $textType,
        isLunar $intType,
        notes $textTypeNullable,
        createdAt $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE task_completions (
        taskId TEXT NOT NULL,
        date TEXT NOT NULL,
        PRIMARY KEY (taskId, date)
      )
    ''');
  }

  // Task operations
  Future<Task> createTask(Task task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id.toString());
  }

  Future<List<Task>> readAllTasks() async {
    final db = await database;
    final result = await db.query('tasks', orderBy: 'createdAt DESC');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> readActiveTasks() async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'isCompleted = ?',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Birthday operations
  Future<Birthday> createBirthday(Birthday birthday) async {
    final db = await database;
    final id = await db.insert('birthdays', birthday.toMap());
    return birthday.copyWith(id: id.toString());
  }

  Future<List<Birthday>> readAllBirthdays() async {
    final db = await database;
    final result = await db.query('birthdays', orderBy: 'date ASC');
    return result.map((json) => Birthday.fromMap(json)).toList();
  }

  Future<int> updateBirthday(Birthday birthday) async {
    final db = await database;
    return db.update(
      'birthdays',
      birthday.toMap(),
      where: 'id = ?',
      whereArgs: [birthday.id],
    );
  }

  Future<int> deleteBirthday(String id) async {
    final db = await database;
    return await db.delete(
      'birthdays',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }

  // TaskCompletion operations
  Future<void> createTaskCompletion(String taskId, DateTime date) async {
    final db = await database;
    await db.insert(
      'task_completions',
      TaskCompletion(taskId: taskId, date: date).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTaskCompletion(String taskId, DateTime date) async {
    final db = await database;
    await db.delete(
      'task_completions',
      where: 'taskId = ? AND date = ?',
      whereArgs: [taskId, TaskCompletion.getDateOnly(date).toIso8601String()],
    );
  }

  Future<bool> isTaskCompletedOnDate(String taskId, DateTime date) async {
    final db = await database;
    final result = await db.query(
      'task_completions',
      where: 'taskId = ? AND date = ?',
      whereArgs: [taskId, TaskCompletion.getDateOnly(date).toIso8601String()],
    );
    return result.isNotEmpty;
  }

  Future<List<DateTime>> getCompletedDatesForTask(String taskId) async {
    final db = await database;
    final result = await db.query(
      'task_completions',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'date DESC',
    );
    return result.map((row) => DateTime.parse(row['date'] as String)).toList();
  }
}
