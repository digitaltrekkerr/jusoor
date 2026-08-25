import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:history/history.dart';

void main() {
  late TranslationDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    AppDatabase.setInstance(
      factory: databaseFactoryFfi,
      dbPath: p.join(Directory.systemTemp.path, 'test_translation_history.db'),
    );
  });

  setUp(() async {
    dao = TranslationDao();
    // Clean slate before every test.
    await dao.deleteAll();
  });

  tearDownAll(() async {
    await AppDatabase.resetInstance();
  });

  // ── Helper ──────────────────────────────────────────────────────────────

  TranslationRecord makeRecord({
    int? createdAt,
    String inputText = 'Hello',
    String outputText = 'Hola',
    String targetLanguage = 'es',
    String? sourceLanguage = 'en',
    String inputType = 'text',
    String modelUsed = 'gpt-4o',
  }) {
    return TranslationRecord(
      createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
      inputText: inputText,
      outputText: outputText,
      targetLanguage: targetLanguage,
      sourceLanguage: sourceLanguage,
      inputType: inputType,
      modelUsed: modelUsed,
    );
  }

  // ── Insert & Retrieve ───────────────────────────────────────────────────

  test(
    'insert 5 records and retrieve them in correct order (newest first)',
    () async {
      final baseTime = DateTime(2025, 1, 1).millisecondsSinceEpoch;

      for (var i = 0; i < 5; i++) {
        await dao.insert(
          makeRecord(
            createdAt: baseTime + i * 1000,
            inputText: 'Input $i',
            outputText: 'Output $i',
          ),
        );
      }

      final records = await dao.getAll();
      expect(records, hasLength(5));
      // Newest first → indices decrease.
      expect(records[0].inputText, 'Input 4');
      expect(records[4].inputText, 'Input 0');
    },
  );

  // ── Search ──────────────────────────────────────────────────────────────

  test('search returns records matching a keyword in input text', () async {
    await dao.insert(
      makeRecord(
        inputText: 'The weather is sunny',
        outputText: 'El clima está soleado',
      ),
    );
    await dao.insert(
      makeRecord(
        inputText: 'I like programming',
        outputText: 'Me gusta programar',
      ),
    );

    final results = await dao.search('weather');
    expect(results, hasLength(1));
    expect(results.first.inputText, 'The weather is sunny');
  });

  test('search returns records matching a keyword in output text', () async {
    await dao.insert(
      makeRecord(
        inputText: 'The weather is sunny',
        outputText: 'El clima está soleado',
      ),
    );
    await dao.insert(
      makeRecord(
        inputText: 'I like programming',
        outputText: 'Me gusta programar',
      ),
    );

    final results = await dao.search('programar');
    expect(results, hasLength(1));
    expect(results.first.outputText, 'Me gusta programar');
  });

  test('search with non-existent keyword returns empty list', () async {
    await dao.insert(makeRecord(inputText: 'Hello world'));

    final results = await dao.search('xyzzy');
    expect(results, isEmpty);
  });

  // ── Delete ──────────────────────────────────────────────────────────────

  test('delete removes a single record', () async {
    final id = await dao.insert(makeRecord(inputText: 'To be deleted'));
    await dao.insert(makeRecord(inputText: 'To remain'));

    await dao.delete(id);

    final remaining = await dao.getAll();
    expect(remaining, hasLength(1));
    expect(remaining.first.inputText, 'To remain');
  });

  test('deleteAll removes every record', () async {
    await dao.insert(makeRecord(inputText: 'A'));
    await dao.insert(makeRecord(inputText: 'B'));

    await dao.deleteAll();

    final remaining = await dao.getAll();
    expect(remaining, isEmpty);
  });

  // ── getById ─────────────────────────────────────────────────────────────

  test('getById returns the correct record', () async {
    final id = await dao.insert(makeRecord(inputText: 'Unique input'));

    final record = await dao.getById(id);
    expect(record, isNotNull);
    expect(record!.inputText, 'Unique input');
  });

  test('getById returns null for non-existent id', () async {
    final record = await dao.getById(99999);
    expect(record, isNull);
  });

  // ── Search sync ────────────────────────────────────────────────────────────

  test('search stays in sync after insert', () async {
    await dao.insert(
      makeRecord(
        inputText: 'Artificial intelligence is fascinating',
        outputText: 'La inteligencia artificial es fascinante',
      ),
    );

    // LIKE query should match "artificial" in input text.
    final results = await dao.search('artificial');
    expect(results, hasLength(1));
    expect(results.first.inputText, 'Artificial intelligence is fascinating');
  });

  test('search stays in sync after delete', () async {
    final id = await dao.insert(
      makeRecord(
        inputText: 'Quantum computing breakthrough',
        outputText: 'Avance en computación cuántica',
      ),
    );

    // Verify the record is found.
    var results = await dao.search('quantum');
    expect(results, hasLength(1));

    // Delete the record.
    await dao.delete(id);

    // The search should no longer return it.
    results = await dao.search('quantum');
    expect(results, isEmpty);
  });

  // ── HistoryService integration ──────────────────────────────────────────

  test(
    'HistoryService.save stores a record with auto-generated timestamp',
    () async {
      final service = HistoryService();
      final id = await service.save(
        inputText: 'Good morning',
        outputText: 'Buenos días',
        targetLanguage: 'es',
        sourceLanguage: 'en',
        modelUsed: 'gpt-4o',
      );

      expect(id, greaterThan(0));

      final record = await service.getById(id);
      expect(record, isNotNull);
      // After the `isNotNull` assertion the analyzer promotes the type,
      // so the `!` operator is unnecessary.
      final saved = record!;
      expect(saved.inputText, 'Good morning');
      expect(saved.outputText, 'Buenos días');
      expect(saved.createdAt, greaterThan(0));
    },
  );
}
