import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'database_schema.dart';

/// Owns the SQLite connection. All memories stay on this device.
final class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const fileName = 'pocket_brain.db';

  /// Opens the on-disk database; desktop platforms use the FFI factory.
  static Future<AppDatabase> open() async {
    final factory = _factoryForPlatform();
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return AppDatabase._(
      await factory.openDatabase(p.join(dir.path, fileName), options: _options()),
    );
  }

  /// A fresh in-memory database, for tests.
  static Future<AppDatabase> inMemory() async {
    sqfliteFfiInit();
    return AppDatabase._(
      await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: _options(singleInstance: false),
      ),
    );
  }

  static DatabaseFactory _factoryForPlatform() {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  static OpenDatabaseOptions _options({bool singleInstance = true}) => OpenDatabaseOptions(
    version: DatabaseSchema.version,
    singleInstance: singleInstance,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, _) => DatabaseSchema.create(db),
    onUpgrade: DatabaseSchema.migrate,
  );

  Future<void> close() => db.close();
}
