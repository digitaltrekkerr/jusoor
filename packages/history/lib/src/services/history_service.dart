import '../dao/translation_dao.dart';
import '../models/translation_record.dart';

/// High-level service for translation history.
///
/// Wraps [TranslationDao] and adds convenience defaults (e.g. auto-generated
/// timestamps). Prefer using this class from presentation / domain layers
/// rather than accessing the DAO directly.
class HistoryService {
  final TranslationDao _dao;

  /// Creates the service.
  ///
  /// Defaults to a [TranslationDao] backed by [AppDatabase.instance] when
  /// [dao] is omitted.
  HistoryService({TranslationDao? dao}) : _dao = dao ?? TranslationDao();

  /// Persists a translation record and returns the auto-generated row id.
  ///
  /// [createdAt] is set automatically to `DateTime.now()` in milliseconds
  /// since epoch.
  Future<int> save({
    required String inputText,
    required String outputText,
    required String targetLanguage,
    String? sourceLanguage,
    String inputType = 'text',
    required String modelUsed,
    int? wordCount,
    String? fileName,
  }) async {
    final record = TranslationRecord(
      createdAt: DateTime.now().millisecondsSinceEpoch,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      inputText: inputText,
      outputText: outputText,
      inputType: inputType,
      modelUsed: modelUsed,
      wordCount: wordCount,
      fileName: fileName,
    );
    return _dao.insert(record);
  }

  /// Restores a previously deleted record, preserving its original ID.
  ///
  /// Unlike [save], this method does not generate a new ID or timestamp —
  /// it inserts the record exactly as provided. Use this when undoing a
  /// delete so that references to the original record remain valid.
  Future<void> insertWithId(TranslationRecord record) async {
    await _dao.insertWithId(record);
  }

  /// Returns every translation record, newest first.
  Future<List<TranslationRecord>> getAll() => _dao.getAll();

  /// Returns the translation with the given [id], or `null`.
  Future<TranslationRecord?> getById(int id) => _dao.getById(id);

  /// Searches translation history using LIKE-based text matching.
  Future<List<TranslationRecord>> search(String query) => _dao.search(query);

  /// Deletes the translation with the given [id].
  Future<void> delete(int id) => _dao.delete(id);

  /// Deletes all translation history entries.
  Future<void> deleteAll() => _dao.deleteAll();
}
