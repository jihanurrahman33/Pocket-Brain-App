import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/entities/task_item.dart';
import '../../domain/repositories/task_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/database_schema.dart';
import '../mappers/row_mappers.dart';
import 'change_broadcaster.dart';

final class SqliteTaskRepository with ChangeBroadcaster implements TaskRepository {
  SqliteTaskRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  @override
  Future<List<TaskItem>> getAll() async {
    final rows = await _db.query(
      Tables.tasks,
      orderBy: 'is_done ASC, due_at IS NULL, due_at ASC, created_at DESC',
    );
    return rows.map(TaskMapper.fromRow).toList();
  }

  @override
  Future<List<TaskItem>> forMemory(String memoryId) async {
    final rows = await _db.query(Tables.tasks, where: 'memory_id = ?', whereArgs: [memoryId]);
    return rows.map(TaskMapper.fromRow).toList();
  }

  @override
  Future<void> save(TaskItem task) async {
    await _db.insert(
      Tables.tasks,
      TaskMapper.toRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(Tables.tasks, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  @override
  Future<void> clear() async {
    await _db.delete(Tables.tasks);
    notifyChanged();
  }
}
