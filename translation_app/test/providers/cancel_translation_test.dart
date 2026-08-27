import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/services/settings_repository.dart';
import 'package:translation_core/translation_core.dart';

/// Fixed-value notifier doubles, mirroring the pattern used in
/// `history_list_after_translate_test.dart`.
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

void main() {
  group('TranslationNotifier cancel', () {
    late HttpServer server;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // flutter_test installs a mock HttpOverrides (400 responses) once its
      // binding initializes; restore the real networking stack so the flow
      // talks to the local server started below.
      HttpOverrides.global = null;

      // A server that accepts the POST but never responds — the request
      // stays in-flight until the CancelToken aborts it.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        // Drain the body, then hold the connection open.
        await for (final _ in request) {}
        // Keep the response open indefinitely; the client cancels first.
        await Completer<void>().future;
      });

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

      // A distinct fallback profile. If cancel() ever leaked into the
      // fallback retry path, this would run (and hang) — the assertion that
      // the state is [TranslationIdle] proves it did not.
      final fallbackProfile = ProviderProfile(
        id: 'p2',
        name: 'Fallback profile',
        providerType: ProviderType.openaiCompatible,
        apiKeyId: 'k1',
        model: 'fallback-model',
        baseUrl: 'http://127.0.0.1:${server.port}',
      );

      container = ProviderContainer(
        overrides: [
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
            () => _FixedSelectedFallbackProfileNotifier('p2'),
          ),
          apiKeysProvider.overrideWith(() => _FakeApiKeysNotifier()),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await server.close(force: true);
    });

    test(
      'cancel() aborts the in-flight request and lands in Idle without '
      'fallback retry or error state',
      () async {
        final notifier = container.read(translationProvider.notifier);

        final run = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );

        // Let the request reach the pending server, then cancel.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.cancel();
        await run.timeout(const Duration(seconds: 10));

        final state = container.read(translationProvider);
        expect(
          state,
          isA<TranslationIdle>(),
          reason:
              'cancel must settle in Idle — never Error (which would prove '
              'the fallback retry ran) or Done.',
        );
        expect(state, isNot(isA<TranslationError>()));
      },
    );

    test(
      'a subsequent translate() starts a fresh cycle (cancelled token is '
      'not reused)',
      () async {
        final notifier = container.read(translationProvider.notifier);

        final first = notifier.translate(
          const TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        notifier.cancel();
        await first.timeout(const Duration(seconds: 10));
        expect(
          container.read(translationProvider),
          isA<TranslationIdle>(),
        );

        // A second run must leave Loading (the pending server never
        // answers), proving the notifier still drives requests.
        final second = notifier.translate(
          const TranslationRequest(
            inputText: 'Bonjour',
            targetLanguage: 'English',
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(container.read(translationProvider), isA<TranslationLoading>());
        notifier.cancel();
        await second.timeout(const Duration(seconds: 10));
        expect(container.read(translationProvider), isA<TranslationIdle>());
      },
    );
  });
}