import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton wrapper around the sqflite [Database] for translation history.
///
/// The first call to [database] lazily opens (or creates) the SQLite file.
/// Use [setInstance] to inject a custom [DatabaseFactory] for testing with
/// `sqflite_common_ffi`, and [resetInstance] to tear down between test runs.
class AppDatabase {
  static AppDatabase? _instance;
  static Database? _database;

  final DatabaseFactory? _factory;
  final String? _dbPath;

  AppDatabase._({DatabaseFactory? factory, String? dbPath})
    : _factory = factory,
      _dbPath = dbPath;

  /// Returns the shared singleton, creating it on first access.
  static AppDatabase get instance => _instance ??= AppDatabase._();

  /// Replaces the singleton with an instance that uses the given [factory]
  /// and/or [dbPath].
  ///
  /// Intended **only** for testing. Call [resetInstance] in `tearDownAll`.
  static void setInstance({DatabaseFactory? factory, String? dbPath}) {
    _instance = AppDatabase._(factory: factory, dbPath: dbPath);
    _database = null;
  }

  /// Clears the singleton and closes any open database handle.
  ///
  /// Call this in `tearDownAll` when using [setInstance].
  static Future<void> resetInstance() async {
    await _database?.close();
    _instance = null;
    _database = null;
  }

  /// Lazily opens and returns the translation history database.
  ///
  /// On the first call the schema is created via [_onCreate]. If the
  /// database was created with an older schema version, [_onUpgrade]
  /// handles the migration.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final factory = _factory ?? databaseFactory;
    final String path;
    if (_dbPath != null) {
      path = _dbPath;
    } else {
      final dbDir = await getDatabasesPath();
      path = p.join(dbDir, 'translation_history.db');
    }

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Creates the initial schema (version 2): translations table only.
  ///
  /// FTS5 is NOT used because the `sqflite` package relies on the Android
  /// system SQLite which does not bundle the FTS5 extension on all devices.
  /// Search is implemented via `LIKE` queries instead.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        source_language TEXT,
        target_language TEXT NOT NULL,
        input_text TEXT NOT NULL,
        output_text TEXT NOT NULL,
        input_type TEXT NOT NULL,
        model_used TEXT NOT NULL,
        word_count INTEGER,
        file_name TEXT
      )
    ''');
  }

  /// Handles database schema migrations between versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 (with FTS5) to version 2 (without FTS5).
      // Drop the FTS5 virtual table and triggers if they exist.
      // These are safe to drop because the main `translations` table
      // contains all the data — the FTS5 table was just a search index.
      await db.execute('DROP TRIGGER IF EXISTS translations_ai');
      await db.execute('DROP TRIGGER IF EXISTS translations_ad');
      await db.execute('DROP TABLE IF EXISTS translations_fts');
    }
  }
}
