import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Table names, shared by every repository.
abstract final class Tables {
  static const memories = 'memories';
  static const collections = 'collections';
  static const tasks = 'tasks';
  static const conversations = 'conversations';
  static const messages = 'messages';
  static const recentSearches = 'recent_searches';
}

/// Schema creation and migrations.
abstract final class DatabaseSchema {
  static const version = 1;

  static Future<void> create(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE ${Tables.collections} (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          emoji TEXT NOT NULL,
          is_private INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE ${Tables.memories} (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          summary TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL,
          source_url TEXT,
          category TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '[]',
          collection_id TEXT REFERENCES ${Tables.collections}(id) ON DELETE SET NULL,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          last_viewed_at INTEGER,
          ai_generated INTEGER NOT NULL DEFAULT 0,
          embedding BLOB
        )''')
      ..execute('CREATE INDEX idx_memories_created ON ${Tables.memories}(created_at)')
      ..execute('''
        CREATE TABLE ${Tables.tasks} (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          due_at INTEGER,
          reminder_at INTEGER,
          is_done INTEGER NOT NULL DEFAULT 0,
          memory_id TEXT REFERENCES ${Tables.memories}(id) ON DELETE SET NULL,
          created_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE ${Tables.conversations} (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          collection_id TEXT REFERENCES ${Tables.collections}(id) ON DELETE SET NULL,
          created_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE ${Tables.messages} (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL
            REFERENCES ${Tables.conversations}(id) ON DELETE CASCADE,
          role TEXT NOT NULL,
          text TEXT NOT NULL,
          source_ids TEXT NOT NULL DEFAULT '[]',
          grounded INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL
        )''')
      ..execute('''
        CREATE TABLE ${Tables.recentSearches} (
          query TEXT PRIMARY KEY,
          searched_at INTEGER NOT NULL
        )''');
    await batch.commit(noResult: true);
  }

  /// Add a case per version bump; never edit [create] for existing users.
  static Future<void> migrate(Database db, int from, int to) async {}
}
