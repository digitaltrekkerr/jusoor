/// A single translation history entry.
///
/// Maps to a row in the `translations` SQLite table. Use [fromMap] to
/// reconstruct from a database query result and [toMap] to persist.
class TranslationRecord {
  /// Auto-incremented primary key. `null` until the row is inserted.
  final int? id;

  /// Unix epoch in milliseconds when this translation was created.
  final int createdAt;

  /// Detected or user-selected source language code (e.g. `'en'`).
  final String? sourceLanguage;

  /// Target language code (e.g. `'es'`).
  final String targetLanguage;

  /// Original text that was submitted for translation.
  final String inputText;

  /// Translation result returned by the model.
  final String outputText;

  /// How the input was provided: `'text'`, `'file'`, `'image'`, `'screenshot'`.
  final String inputType;

  /// Model identifier used for this translation (e.g. `'gpt-4o'`).
  final String modelUsed;

  /// Word count of the input text, if computed.
  final int? wordCount;

  /// Original file name when [inputType] is `'file'`.
  final String? fileName;

  /// Creates an immutable [TranslationRecord].
  const TranslationRecord({
    this.id,
    required this.createdAt,
    this.sourceLanguage,
    required this.targetLanguage,
    required this.inputText,
    required this.outputText,
    required this.inputType,
    required this.modelUsed,
    this.wordCount,
    this.fileName,
  });

  /// Reconstructs a [TranslationRecord] from a row [map] returned by sqflite.
  ///
  /// Column names use snake_case as stored in SQLite.
  factory TranslationRecord.fromMap(Map<String, dynamic> map) {
    return TranslationRecord(
      id: map['id'] as int?,
      createdAt: map['created_at'] as int,
      sourceLanguage: map['source_language'] as String?,
      targetLanguage: map['target_language'] as String,
      inputText: map['input_text'] as String,
      outputText: map['output_text'] as String,
      inputType: map['input_type'] as String,
      modelUsed: map['model_used'] as String,
      wordCount: map['word_count'] as int?,
      fileName: map['file_name'] as String?,
    );
  }

  /// Serialises the record into a row map suitable for sqflite insertion.
  ///
  /// The `id` key is omitted when `null` so that SQLite assigns the next
  /// auto-increment value on insert.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'created_at': createdAt,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'input_text': inputText,
      'output_text': outputText,
      'input_type': inputType,
      'model_used': modelUsed,
      'word_count': wordCount,
      'file_name': fileName,
    };
  }

  /// Returns a copy of this record with the given field replaced.
  ///
  /// Currently only supports overriding [id] after an insert to capture the
  /// auto-generated value.
  TranslationRecord copyWith({int? id}) {
    return TranslationRecord(
      id: id ?? this.id,
      createdAt: createdAt,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      inputText: inputText,
      outputText: outputText,
      inputType: inputType,
      modelUsed: modelUsed,
      wordCount: wordCount,
      fileName: fileName,
    );
  }
}
