import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history/history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_app/app.dart';
import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/history_provider.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/screens/history_screen.dart';
import 'package:translation_app/services/settings_repository.dart';
import 'package:translation_core/translation_core.dart';

/// In-memory [HistoryService] double so tests never touch the real SQLite
/// database (which needs a platform channel unavailable in unit tests).
///
/// New records are inserted at the front, mirroring the DAO's
/// `ORDER BY created_at DESC` behaviour.
class InMemoryHistoryService implements HistoryService {
  final List<TranslationRecord> _records = [];
  int _nextId = 1;

  @override
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
    final id = _nextId++;
    _records.insert(
      0,
      TranslationRecord(
        id: id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        inputText: inputText,
        outputText: outputText,
        inputType: inputType,
        modelUsed: modelUsed,
        wordCount: wordCount,
        fileName: fileName,
      ),
    );
    return id;
  }

  @override
  Future<void> insertWithId(TranslationRecord record) async {
    _records.insert(0, record);
  }

  @override
  Future<List<TranslationRecord>> getAll() async {
    return List.unmodifiable(_records);
  }

  @override
  Future<TranslationRecord?> getById(int id) async {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    return _records
        .where(
          (r) => r.inputText.contains(query) || r.outputText.contains(query),
        )
        .toList();
  }

  @override
  Future<void> delete(int id) async {
    _records.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> deleteAll() async {
    _records.clear();
  }
}

/// Notifier doubles that return fixed values instead of reading
/// [SettingsRepository], so the translate flow can run without
/// SharedPreferences or secure storage.
class _FixedTemplatesNotifier extends TemplatesNotifier {
  final List<PromptTemplate> _templates;

  _FixedTemplatesNotifier(this._templates);

  @override
  List<PromptTemplate> build() => _templates;
}

class _FixedProfilesNotifier extends ProfilesNotifier {
  final List<ProviderProfile> _profiles;

  _FixedProfilesNotifier(this._profiles);

  @override
  List<ProviderProfile> build() => _profiles;
}

class _FixedSelectedTextTemplateNotifier extends SelectedTextTemplateNotifier {
  final String? _id;

  _FixedSelectedTextTemplateNotifier(this._id);

  @override
  String? build() => _id;
}

class _FixedSelectedImageTemplateNotifier extends SelectedImageTemplateNotifier {
  final String? _id;

  _FixedSelectedImageTemplateNotifier(this._id);

  @override
  String? build() => _id;
}

class _FixedSelectedFallbackProfileNotifier
    extends SelectedFallbackProfileNotifier {
  final String? _id;

  _FixedSelectedFallbackProfileNotifier(this._id);

  @override
  String? build() => _id;
}

class _FakeApiKeysNotifier extends ApiKeysNotifier {
  @override
  List<ApiKeyEntry> build() => const [];

  @override
  Future<String?> getApiKeyValue(String id) async => 'test-api-key';
}

/// Polls [historyListProvider] until it exposes at least [minRecords]
/// records or [timeout] elapses.
///
/// The translation flow fires the history save without awaiting it, so the
/// test must wait for the refresh to land instead of assuming `translate()`
/// completion implies the list is updated.
Future<List<TranslationRecord>> _waitForHistoryRecords(
  ProviderContainer container, {
  int minRecords = 1,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final records = container.read(historyListProvider).value;
    if (records != null && records.length >= minRecords) return records;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('historyListProvider never received $minRecords record(s)');
}

void main() {
  group('history list after a successful translation', () {
    late HttpServer server;
    late ProviderContainer container;
    late InMemoryHistoryService historyService;

    setUp(() async {
      // flutter_test installs a mock HttpOverrides (400 responses) when its
      // binding is initialized, even for plain `test()`s in the same file.
      // The translate flow performs a real HTTP call, so restore the real
      // networking stack for this suite — it only talks to the local server
      // started below.
      HttpOverrides.global = null;

      // Local SSE endpoint that mimics an OpenAI-compatible chat completion
      // stream, so the real translate flow runs end-to-end without network.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        // Drain the request body so the connection completes cleanly.
        await for (final _ in request) {}
        request.response.headers.contentType =
            ContentType('text', 'event-stream', charset: 'utf-8');
        request.response
            .write('data: {"choices":[{"delta":{"content":"Bonjour "}}]}\n\n');
        request.response
            .write('data: {"choices":[{"delta":{"content":"monde"}}]}\n\n');
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      historyService = InMemoryHistoryService();

      const template = PromptTemplate(
        id: 't1',
        profileId: 'p1',
        name: 'Local test template',
        systemPrompt: 'You are a translator.',
        supportsText: true,
        supportsImage: false,
      );

      final profile = ProviderProfile(
        id: 'p1',
        name: 'Local test profile',
        providerType: ProviderType.openaiCompatible,
        apiKeyId: 'k1',
        model: 'test-model',
        baseUrl: 'http://127.0.0.1:${server.port}',
      );

      container = ProviderContainer(
        overrides: [
          historyServiceProvider.overrideWithValue(historyService),
          templatesProvider.overrideWith(
            () => _FixedTemplatesNotifier([template]),
          ),
          profilesProvider.overrideWith(
            () => _FixedProfilesNotifier([profile]),
          ),
          selectedTextTemplateProvider.overrideWith(
            () => _FixedSelectedTextTemplateNotifier('t1'),
          ),
          selectedImageTemplateProvider.overrideWith(
            () => _FixedSelectedImageTemplateNotifier(null),
          ),
          selectedFallbackProfileProvider.overrideWith(
            () => _FixedSelectedFallbackProfileNotifier(null),
          ),
          apiKeysProvider.overrideWith(() => _FakeApiKeysNotifier()),
        ],
      );

      // Warm up the history provider so its initial (empty) load is done
      // before the translation writes anything.
      container.read(historyListProvider);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() async {
      container.dispose();
      await server.close(force: true);
    });

    test(
      'translate() completion makes historyListProvider emit the saved entry '
      'without an app restart',
      () async {
        final notifier = container.read(translationProvider.notifier);

        await notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        // The translation itself succeeded...
        final state = container.read(translationProvider);
        if (state is TranslationError) {
          fail('translate failed with: ${state.message}');
        }
        expect(state, isA<TranslationDone>());

        // ...and the history list picked up the new row automatically. This
        // is the regression assertion: pre-fix, save() wrote to the database
        // but historyListProvider was never refreshed, so it stayed empty
        // until the app restarted.
        final records = await _waitForHistoryRecords(container);
        expect(records, hasLength(1));
        expect(records.single.inputText, 'Hello');
        expect(records.single.outputText, 'Bonjour monde');
        expect(records.single.targetLanguage, 'French');
        expect(records.single.modelUsed, 'test-model');
      },
    );
  });

  group('history empty state pull-to-refresh', () {
    testWidgets('empty history list is wrapped in a RefreshIndicator',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          historyServiceProvider.overrideWithValue(InMemoryHistoryService()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HistoryScreen(),
          ),
        ),
      );
      // Let the async initial load land: loading -> data([]).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No translation history yet'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Pulling down must trigger a reload without crashing or losing the
      // empty state.
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('No translation history yet'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });

  group('history tab reload on switch', () {
    testWidgets(
      'switching to the History tab shows entries saved by another flow',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final historyService = InMemoryHistoryService();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            historyServiceProvider.overrideWithValue(historyService),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(JusoorApp(container: container));
        // Let the settings load and the IndexedStack settle, as in
        // test/widget_test.dart.
        await tester.pump(const Duration(seconds: 2));

        // History tab starts empty.
        await tester.tap(find.byIcon(Icons.history_outlined));
        await tester.pump();
        expect(find.text('No translation history yet'), findsOneWidget);

        // Simulate another flow (e.g. the overlay screen) saving directly
        // through the history service while the user is on another tab.
        await historyService.save(
          inputText: 'Bonjour',
          outputText: 'Hello',
          targetLanguage: 'English',
          modelUsed: 'test-model',
        );

        // Leave and come back — the new entry must appear without a restart.
        await tester.tap(find.byIcon(Icons.translate_outlined));
        await tester.pump();
        await tester.tap(find.byIcon(Icons.history_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Bonjour'), findsOneWidget);
        expect(find.text('No translation history yet'), findsNothing);
      },
    );
  });
}