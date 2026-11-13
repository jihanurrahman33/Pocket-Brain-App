import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/entities/memory_collection.dart';
import '../../domain/repositories/collection_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/database_schema.dart';
import '../mappers/row_mappers.dart';
import 'change_broadcaster.dart';

final class SqliteCollectionRepository with ChangeBroadcaster implements CollectionRepository {
  SqliteCollectionRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const _selectWithCounts =
      '''
    SELECT c.*, (SELECT COUNT(*) FROM ${Tables.memories} m
                 WHERE m.collection_id = c.id AND m.is_archived = 0) AS memory_count
    FROM ${Tables.collections} c''';

  @override
  Future<List<MemoryCollection>> getAll() async {
    final rows = await _db.rawQuery('$_selectWithCounts ORDER BY c.name COLLATE NOCASE');
    return rows.map(CollectionMapper.fromRow).toList();
  }

  @override
  Future<MemoryCollection?> getById(String id) async {
    final rows = await _db.rawQuery('$_selectWithCounts WHERE c.id = ?', [id]);
    return rows.isEmpty ? null : CollectionMapper.fromRow(rows.single);
  }

  @override
  Future<void> save(MemoryCollection collection) async {
    await _db.insert(
      Tables.collections,
      CollectionMapper.toRow(collection),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(Tables.collections, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  @override
  Future<void> clear() async {
    await _db.delete(Tables.collections);
    notifyChanged();
  }
}
