import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history/history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_app/providers/history_provider.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/services/settings_repository.dart';
import 'package:translation_core/translation_core.dart';

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

class _FixedSelectedImageTemplateNotifier
    extends SelectedImageTemplateNotifier {
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

class InMemoryHistoryService implements HistoryService {
  final List<TranslationRecord> saved = [];
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
    saved.insert(
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
    saved.insert(0, record);
  }

  @override
  Future<List<TranslationRecord>> getAll() async => List.unmodifiable(saved);

  @override
  Future<TranslationRecord?> getById(int id) async {
    for (final record in saved) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<List<TranslationRecord>> search(String query) async {
    return saved
        .where(
          (r) => r.inputText.contains(query) || r.outputText.contains(query),
        )
        .toList();
  }

  @override
  Future<void> delete(int id) async {
    saved.removeWhere((r) => r.id == id);
  }

  @override
  Future<void> deleteAll() async {
    saved.clear();
  }
}

typedef RequestHandler = Future<void> Function(HttpRequest request);

ProviderContainer _buildContainer({
  required int port,
  required InMemoryHistoryService historyService,
  String? fallbackProfileId = 'p2',
}) {
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
    baseUrl: 'http://127.0.0.1:$port',
  );

  final fallbackProfile = ProviderProfile(
    id: 'p2',
    name: 'Fallback profile',
    providerType: ProviderType.openaiCompatible,
    apiKeyId: 'k1',
    model: 'fallback-model',
    baseUrl: 'http://127.0.0.1:$port',
  );

  return ProviderContainer(
    overrides: [
      historyServiceProvider.overrideWithValue(historyService),
      templatesProvider.overrideWith(() => _FixedTemplatesNotifier([template])),
      profilesProvider.overrideWith(
        () => _FixedProfilesNotifier([profile, fallbackProfile]),
      ),
      selectedTextTemplateProvider.overrideWith(
        () => _FixedSelectedTextTemplateNotifier('t1'),
      ),
      selectedImageTemplateProvider.overrideWith(
        () => _FixedSelectedImageTemplateNotifier(null),
      ),
      selectedFallbackProfileProvider.overrideWith(
        () => _FixedSelectedFallbackProfileNotifier(fallbackProfileId),
      ),
      apiKeysProvider.overrideWith(() => _FakeApiKeysNotifier()),
    ],
  );
}

void main() {
  group('TranslationNotifier clearAll', () {
    late HttpServer server;
    late ProviderContainer container;
    late InMemoryHistoryService historyService;
    late RequestHandler requestHandler;
    var requestCount = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      HttpOverrides.global = null;
      historyService = InMemoryHistoryService();
      requestCount = 0;
      requestHandler = (request) async {
        await for (final _ in request) {}
        await Completer<void>().future;
      };

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestCount++;
        await requestHandler(request);
      });

      container = _buildContainer(
        port: server.port,
        historyService: historyService,
      );
    });

    tearDown(() async {
      container.dispose();
      await server.close(force: true);
    });

    test(
      'clearAll() while TranslationLoading lands in TranslationIdle and aborts '
      'the request',
      () async {
        final notifier = container.read(translationProvider.notifier);
        final run = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.clearAll();
        await run.timeout(const Duration(seconds: 10));

        final state = container.read(translationProvider);
        expect(state, isA<TranslationIdle>());
        expect(state, isNot(isA<TranslationError>()));
        expect(notifier.hasLiveRequest, isFalse);
      },
    );

    test(
      'clearAll() while Streaming: state stays Idle and no late chunk '
      'resurrects it',
      () async {
        final chunkSent = Completer<void>();
        final holdResponse = Completer<void>();
        requestHandler = (request) async {
          await for (final _ in request) {}
          request.response.bufferOutput = false;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
          );
          await request.response.flush();
          if (!chunkSent.isCompleted) chunkSent.complete();
          await holdResponse.future;
          try {
            await request.response.close();
          } catch (_) {}
        };

        final notifier = container.read(translationProvider.notifier);
        final states = <TranslationState>[];
        container.listen(translationProvider, (_, next) => states.add(next));

        final run = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        try {
          await chunkSent.future.timeout(const Duration(seconds: 5));
          final deadline = DateTime.now().add(const Duration(seconds: 5));
          while (container.read(translationProvider) is! TranslationStreaming) {
            if (DateTime.now().isAfter(deadline)) {
              fail(
                'never reached TranslationStreaming; states=$states '
                'current=${container.read(translationProvider)} '
                'requests=$requestCount',
              );
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }

          notifier.clearAll();
          expect(container.read(translationProvider), isA<TranslationIdle>());

          await Future<void>.delayed(const Duration(milliseconds: 300));
          expect(container.read(translationProvider), isA<TranslationIdle>());
          expect(
            states.whereType<TranslationStreaming>().length,
            greaterThanOrEqualTo(1),
          );
          expect(states.last, isA<TranslationIdle>());
        } finally {
          if (!holdResponse.isCompleted) holdResponse.complete();
        }
        await run.timeout(const Duration(seconds: 10));
        expect(container.read(translationProvider), isA<TranslationIdle>());
      },
    );

    test(
      'clearAll() writes no history row and never reaches TranslationDone',
      () async {
        requestHandler = (request) async {
          await for (final _ in request) {}
          request.response.bufferOutput = false;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"Bonjour"}}]}\n\n',
          );
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 300));
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        };

        final notifier = container.read(translationProvider.notifier);
        final run = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 150));
        notifier.clearAll();
        await run.timeout(const Duration(seconds: 10));
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(container.read(translationProvider), isA<TranslationIdle>());
        expect(historyService.saved, isEmpty);
      },
    );

    test('double clearAll() is idempotent', () async {
      final notifier = container.read(translationProvider.notifier);
      final run = notifier.translate(
        const TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'French',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      notifier.clearAll();
      notifier.clearAll();
      await run.timeout(const Duration(seconds: 10));

      expect(container.read(translationProvider), isA<TranslationIdle>());
      expect(notifier.hasLiveRequest, isFalse);

      notifier.clearAll();
      expect(container.read(translationProvider), isA<TranslationIdle>());
      expect(notifier.hasLiveRequest, isFalse);
    });

    test(
      'cancel() after clearAll() is a no-op and cannot re-arm',
      () async {
        final notifier = container.read(translationProvider.notifier);
        final run = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.clearAll();
        await run.timeout(const Duration(seconds: 10));

        notifier.cancel();
        expect(notifier.hasLiveRequest, isFalse);
        expect(container.read(translationProvider), isA<TranslationIdle>());

        final second = notifier.translate(
          const TranslationRequest(
            inputText: 'Bonjour',
            targetLanguage: 'English',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(container.read(translationProvider), isA<TranslationLoading>());
        notifier.clearAll();
        await second.timeout(const Duration(seconds: 10));
        expect(container.read(translationProvider), isA<TranslationIdle>());
      },
    );

    test(
      'clearAll() during a failing primary does not run the fallback',
      () async {
        final holdError = Completer<void>();
        requestHandler = (request) async {
          await for (final _ in request) {}
          await holdError.future;
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write('{"error":"boom"}');
          await request.response.close();
        };

        final notifier = container.read(translationProvider.notifier);
        final run = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.clearAll();
        holdError.complete();
        await run.timeout(const Duration(seconds: 10));
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(container.read(translationProvider), isA<TranslationIdle>());
        expect(
          container.read(translationProvider),
          isNot(isA<TranslationError>()),
        );
        expect(requestCount, 1);
      },
    );
  });
}
