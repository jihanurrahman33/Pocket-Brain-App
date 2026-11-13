import 'dart:typed_data';

import 'package:sqflite_common/utils/utils.dart' as sql_utils;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/entities/memory.dart';
import '../../domain/entities/search.dart';
import '../../domain/repositories/memory_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/database_schema.dart';
import '../mappers/row_mappers.dart';
import 'change_broadcaster.dart';

final class SqliteMemoryRepository
    with ChangeBroadcaster
    implements MemoryRepository, MemoryMetadataStore {
  SqliteMemoryRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  static const _notArchived = 'is_archived = 0';
  static const _newestFirst = 'created_at DESC';
  static const _recentlyViewedLimit = 30;

  @override
  Future<void> save(Memory memory) async {
    await _db.insert(
      Tables.memories,
      MemoryMapper.toRow(memory),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChanged();
  }

  @override
  Future<Memory?> getById(String id) async {
    final rows = await _db.query(Tables.memories, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MemoryMapper.fromRow(rows.single);
  }

  @override
  Future<List<Memory>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await _db.query(Tables.memories, where: 'id IN ($placeholders)', whereArgs: ids);
    final byId = {for (final r in rows) r['id']: MemoryMapper.fromRow(r)};
    return [for (final id in ids) ?byId[id]];
  }

  @override
  Future<List<Memory>> query(MemoryQuery query) async {
    final where = <String>[
      if (query.filter == MemoryFilter.archived) 'is_archived = 1' else _notArchived,
      if (query.filter == MemoryFilter.favorites) 'is_favorite = 1',
      if (query.filter == MemoryFilter.recentlyViewed) 'last_viewed_at IS NOT NULL',
      if (query.collectionId != null) 'collection_id = ?',
      if (query.category != null) 'category = ?',
    ];
    final recent = query.filter == MemoryFilter.recentlyViewed;
    final rows = await _db.query(
      Tables.memories,
      where: where.join(' AND '),
      whereArgs: [?query.collectionId, ?query.category],
      orderBy: recent ? 'last_viewed_at DESC' : _newestFirst,
      limit: query.limit ?? (recent ? _recentlyViewedLimit : null),
    );
    return rows.map(MemoryMapper.fromRow).toList();
  }

  @override
  Future<List<Memory>> getAll({bool includeArchived = false}) async {
    final rows = await _db.query(
      Tables.memories,
      where: includeArchived ? null : _notArchived,
      orderBy: _newestFirst,
    );
    return rows.map(MemoryMapper.fromRow).toList();
  }

  @override
  Future<List<Memory>> savedBetween(DateTime from, DateTime to) async {
    final rows = await _db.query(
      Tables.memories,
      where: 'created_at >= ? AND created_at < ? AND $_notArchived',
      whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
      orderBy: _newestFirst,
    );
    return rows.map(MemoryMapper.fromRow).toList();
  }

  @override
  Future<List<Memory>> notViewedSince(DateTime cutoff, {required int limit}) async {
    final ms = cutoff.millisecondsSinceEpoch;
    final rows = await _db.query(
      Tables.memories,
      where:
          '$_notArchived AND created_at < ? AND '
          '(last_viewed_at IS NULL OR last_viewed_at < ?)',
      whereArgs: [ms, ms],
      orderBy: 'COALESCE(last_viewed_at, created_at) ASC',
      limit: limit,
    );
    return rows.map(MemoryMapper.fromRow).toList();
  }

  @override
  Future<int> count() async =>
      sql_utils.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM ${Tables.memories} WHERE $_notArchived'),
      ) ??
      0;

  @override
  Future<List<String>> categories() async {
    final rows = await _db.rawQuery(
      'SELECT category, COUNT(*) AS n FROM ${Tables.memories} '
      'WHERE $_notArchived GROUP BY category ORDER BY n DESC',
    );
    return rows.map((r) => r['category']! as String).toList();
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(Tables.memories, where: 'id = ?', whereArgs: [id]);
    notifyChanged();
  }

  @override
  Future<void> clear() async {
    await _db.delete(Tables.memories);
    notifyChanged();
  }

  // ------------------------------------------------- MemoryMetadataStore

  @override
  Future<void> markViewed(String id, DateTime at) => _db.update(
    Tables.memories,
    {'last_viewed_at': at.millisecondsSinceEpoch},
    where: 'id = ?',
    whereArgs: [id],
  );

  @override
  Future<void> setEmbedding(String id, Float32List vector) => _db.update(
    Tables.memories,
    {'embedding': MemoryMapper.vectorToBytes(vector)},
    where: 'id = ?',
    whereArgs: [id],
  );

  @override
  Future<List<Memory>> withoutEmbedding() async {
    final rows = await _db.query(Tables.memories, where: 'embedding IS NULL');
    return rows.map(MemoryMapper.fromRow).toList();
  }
}
