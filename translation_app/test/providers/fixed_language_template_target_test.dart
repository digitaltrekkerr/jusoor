import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_core/translation_core.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/screens/home_screen.dart';

/// Records the outgoing [TranslationRequest] instead of running a network
/// call, so the test can assert exactly what the home screen sends for a
/// fixed output-language template.
class _RecordingTranslationNotifier extends TranslationNotifier {
  TranslationRequest? capturedRequest;

  @override
  Future<void> translate(TranslationRequest request) async {
    capturedRequest = request;
  }
}

class _FixedTemplatesNotifier extends TemplatesNotifier {
  final List<PromptTemplate> _templates;

  _FixedTemplatesNotifier(this._templates);

  @override
  List<PromptTemplate> build() => _templates;
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

void main() {
  group('fixed output-language template — outgoing target language', () {
    const fixedTemplate = PromptTemplate(
      id: 'fixed-t1',
      profileId: 'p1',
      name: 'Fixed language template',
      systemPrompt: 'Translate the text into {{target_language}}.',
      supportsText: true,
      supportsImage: false,
      outputLanguageFixed: true,
    );

    testWidgets(
      'translate() receives the persisted target language, not the auto sentinel',
      (tester) async {
        // Persisted default target language. This is the language the
        // fixed template's `{{target_language}}` placeholder must resolve
        // to — pre-fix, home_screen sent the literal 'auto' sentinel and
        // the model echoed the source text unchanged.
        SharedPreferences.setMockInitialValues({
          'default_target_language': 'French',
        });
        final prefs = await SharedPreferences.getInstance();

        final recording = _RecordingTranslationNotifier();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            templatesProvider.overrideWith(
              () => _FixedTemplatesNotifier(const [fixedTemplate]),
            ),
            selectedTextTemplateProvider.overrideWith(
              () => _FixedSelectedTextTemplateNotifier('fixed-t1'),
            ),
            selectedImageTemplateProvider.overrideWith(
              () => _FixedSelectedImageTemplateNotifier(null),
            ),
            translationProvider.overrideWith(() => recording),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [Locale('en', ''), Locale('ar', '')],
              home: HomeScreen(),
            ),
          ),
        );
        await tester.pump();

        // The fixed template hides the target-language selector.
        expect(find.text('Target'), findsNothing);

        await tester.enterText(find.byType(TextField), 'Hello world');
        // Rebuild the action row so the Translate button becomes enabled.
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
        await tester.pump();

        final request = recording.capturedRequest;
        expect(request, isNotNull, reason: 'translate() must be invoked');
        expect(
          request!.targetLanguage,
          'French',
          reason: 'the persisted default target language must be sent, '
              'not the auto sentinel',
        );
        expect(request.targetLanguage, isNot('auto'));
        // The V1 wire shape: the request carries no thinking/stream toggles.
        expect(request.substituteTargetLanguage, isTrue);
      },
    );

    testWidgets(
      'non-fixed template still receives the persisted target language',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'default_target_language': 'Italian',
        });
        final prefs = await SharedPreferences.getInstance();

        const nonFixedTemplate = PromptTemplate(
          id: 'normal-t1',
          profileId: 'p1',
          name: 'Normal template',
          systemPrompt: 'Translate the text into {{target_language}}.',
          supportsText: true,
          supportsImage: false,
          outputLanguageFixed: false,
        );

        final recording = _RecordingTranslationNotifier();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            templatesProvider.overrideWith(
              () => _FixedTemplatesNotifier(const [nonFixedTemplate]),
            ),
            selectedTextTemplateProvider.overrideWith(
              () => _FixedSelectedTextTemplateNotifier('normal-t1'),
            ),
            selectedImageTemplateProvider.overrideWith(
              () => _FixedSelectedImageTemplateNotifier(null),
            ),
            translationProvider.overrideWith(() => recording),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: [Locale('en', ''), Locale('ar', '')],
              home: HomeScreen(),
            ),
          ),
        );
        await tester.pump();

        // Non-fixed template keeps the selector visible.
        expect(find.text('Target'), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'Ciao mondo');
        // Rebuild the action row so the Translate button becomes enabled.
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Translate'));
        await tester.pump();

        expect(recording.capturedRequest, isNotNull);
        expect(recording.capturedRequest!.targetLanguage, 'Italian');
        expect(recording.capturedRequest!.substituteTargetLanguage, isTrue);
      },
    );
  });
}