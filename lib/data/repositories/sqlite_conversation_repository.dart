import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../../domain/repositories/search_history_repository.dart';
import '../datasources/local/app_database.dart';
import '../datasources/local/database_schema.dart';
import '../mappers/row_mappers.dart';

final class SqliteConversationRepository implements ConversationRepository {
  SqliteConversationRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  @override
  Future<List<Conversation>> getAll() async {
    final rows = await _db.query(Tables.conversations, orderBy: 'created_at DESC');
    return rows.map(ConversationMapper.fromRow).toList();
  }

  @override
  Future<void> save(Conversation conversation) => _db.insert(
    Tables.conversations,
    ConversationMapper.toRow(conversation),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  @override
  Future<void> delete(String id) =>
      _db.delete(Tables.conversations, where: 'id = ?', whereArgs: [id]);

  @override
  Future<List<ChatMessage>> messages(String conversationId) async {
    final rows = await _db.query(
      Tables.messages,
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ConversationMapper.messageFromRow).toList();
  }

  @override
  Future<void> saveMessage(ChatMessage message) => _db.insert(
    Tables.messages,
    ConversationMapper.messageToRow(message),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  @override
  Future<void> deleteMessage(String id) =>
      _db.delete(Tables.messages, where: 'id = ?', whereArgs: [id]);

  @override
  Future<void> clear() async {
    await _db.delete(Tables.messages);
    await _db.delete(Tables.conversations);
  }
}

final class SqliteSearchHistoryRepository implements SearchHistoryRepository {
  SqliteSearchHistoryRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  @override
  Future<List<String>> recent({required int limit}) async {
    final rows = await _db.query(Tables.recentSearches, orderBy: 'searched_at DESC', limit: limit);
    return rows.map((r) => r['query']! as String).toList();
  }

  @override
  Future<void> add(String query, DateTime at) => _db.insert(Tables.recentSearches, {
    'query': query,
    'searched_at': at.millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  @override
  Future<void> clear() => _db.delete(Tables.recentSearches);
}
