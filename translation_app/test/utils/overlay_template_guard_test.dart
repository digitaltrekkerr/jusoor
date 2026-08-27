import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';
import 'package:translation_app/utils/overlay_template_guard.dart';

void main() {
  group('overlayTemplateGuardError — outputLanguageFixed guard', () {
    const textTemplate = PromptTemplate(
      id: 'fixed-text',
      profileId: 'p1',
      name: 'Fixed language text template',
      systemPrompt: 'Translate to Arabic always.',
      supportsText: true,
      supportsImage: false,
      outputLanguageFixed: true,
    );

    const imageTemplate = PromptTemplate(
      id: 'fixed-image',
      profileId: 'p1',
      name: 'Fixed language image template',
      systemPrompt: 'Translate to Arabic always.',
      supportsText: false,
      supportsImage: true,
      outputLanguageFixed: true,
    );

    const freeTemplate = PromptTemplate(
      id: 'free',
      profileId: 'p1',
      name: 'Normal template',
      systemPrompt: 'Translate into {{target_language}}.',
      supportsText: true,
      supportsImage: true,
      outputLanguageFixed: false,
    );

    test('rejects a fixed-language text template with the overlay error', () {
      final error = overlayTemplateGuardError(textTemplate);
      expect(error, isNotNull);
      expect(error, contains('fixed output language'));
      expect(error, contains('not compatible with floating overlay translation'));
      expect(error, contains('app Settings to pick a different overlay template'));
    });

    test('rejects a fixed-language image template with the same error', () {
      final error = overlayTemplateGuardError(imageTemplate);
      expect(error, isNotNull);
      expect(error, contains('fixed output language'));
      expect(error, contains('not compatible with floating overlay translation'));
    });

    test('allows templates that do not fix the output language', () {
      expect(overlayTemplateGuardError(freeTemplate), isNull);
    });

    test(
      'message is identical to the IPC overlay_handlers rejection message',
      () {
        // The IPC overlay path (overlay_handlers.dart, text ~L154 and image
        // ~L255) rejects fixed-language templates with this exact wording.
        // The in-app overlay path must reject with the SAME message so both
        // surfaces behave consistently.
        expect(
          kOverlayFixedLanguageError,
          'Error: Selected template has a fixed output language and is not '
          'compatible with floating overlay translation. Please open app '
          'Settings to pick a different overlay template.',
        );
      },
    );
  });
}