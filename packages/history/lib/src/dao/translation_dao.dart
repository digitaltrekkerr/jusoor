import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/translation_record.dart';

/// Data-access object for the `translations` table.
///
/// All CRUD helpers delegate to the [AppDatabase] singleton. Pass a custom
/// [dbHelper] when you need to inject a test double.
class TranslationDao {
  final AppDatabase _dbHelper;

  /// Creates the DAO.
  ///
  /// Defaults to [AppDatabase.instance] when [dbHelper] is omitted.
  TranslationDao({AppDatabase? dbHelper})
    : _dbHelper = dbHelper ?? AppDatabase.instance;

  /// Inserts [record] and returns the auto-generated row id.
  Future<int> insert(TranslationRecord record) async {
    final db = await _dbHelper.database;
    return db.insert('translations', record.toMap());
  }

  /// Inserts [record] preserving its existing ID.
  ///
  /// Use this for restoring a previously deleted record so that its
  /// original ID is maintained. Uses [ConflictAlgorithm.replace] so that
  /// an insert with the same ID overwrites any conflicting row.
  Future<void> insertWithId(TranslationRecord record) async {
    final db = await _dbHelper.database;
    await db.insert(
      'translations',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every translation ordered newest-first.
  Future<List<TranslationRecord>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('translations', orderBy: 'created_at DESC');
    return maps.map(TranslationRecord.fromMap).toList();
  }

  /// Returns the translation with the given [id], or `null` if not found.
  Future<TranslationRecord?> getById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'translations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TranslationRecord.fromMap(maps.first);
  }

  /// Searches translation history using SQL LIKE queries.
  ///
  /// Each word in [query] is treated as a separate search term. A record
  /// matches if ANY of its `input_text` or `output_text` columns contain
  /// ALL of the search words (AND logic).
  ///
  /// This replaces the previous FTS5-based search which required the FTS5
  /// SQLite extension that is not available on all Android devices.
  Future<List<TranslationRecord>> search(String query) async {
    final db = await _dbHelper.database;

    final words = query.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return [];

    // Build WHERE clause: each word must match in input_text OR output_text.
    // e.g., for ["hello", "world"]:
    // (input_text LIKE ? OR output_text LIKE ?) AND (input_text LIKE ? OR output_text LIKE ?)
    final conditions = <String>[];
    final args = <String>[];
    for (final word in words) {
      conditions.add(
        "(input_text LIKE ? ESCAPE '\\' OR output_text LIKE ? ESCAPE '\\')",
      );
      args.add('%${_escapeLike(word)}%');
      args.add('%${_escapeLike(word)}%');
    }

    final whereClause = conditions.join(' AND ');

    final maps = await db.query(
      'translations',
      where: whereClause,
      whereArgs: args,
      orderBy: 'created_at DESC',
    );
    return maps.map(TranslationRecord.fromMap).toList();
  }

  /// Escapes SQL LIKE wildcard characters (`%`, `_`) and the escape
  /// character itself (`\`) so they are treated as literals in a LIKE
  /// pattern when used with `ESCAPE '\'`.
  static String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }

  /// Deletes the row with the given [id].
  Future<void> delete(int id) async {
    final db = await _dbHelper.database;
    await db.delete('translations', where: 'id = ?', whereArgs: [id]);
  }

  /// Deletes every row from the translations table.
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('translations');
  }
}
