import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/services/settings_repository.dart';

void main() {
  group('SettingsRepository.builtInSystemPromptFor', () {
    test('returns the reconstruction prompt for the Gemini template', () {
      final prompt = SettingsRepository.builtInSystemPromptFor(
        'gemini_translator_template',
      );
      expect(prompt, isNotNull);
      expect(
        prompt,
        SettingsRepository.geminiReconstructionTemplatePrompt,
        reason: 'Reset to Default must restore the template\'s own '
            'formatting-reconstruction prompt, not a generic placeholder',
      );
    });

    test('returns the generic expert prompt for OpenRouter/OpenAI templates',
        () {
      expect(
        SettingsRepository.builtInSystemPromptFor(
          'professional_translator_template',
        ),
        SettingsRepository.systemPromptTemplate,
      );
      expect(
        SettingsRepository.builtInSystemPromptFor(
          'openai_translator_template',
        ),
        SettingsRepository.systemPromptTemplate,
      );
    });

    test('prompts contain the target-language placeholder', () {
      for (final id in const [
        'professional_translator_template',
        'gemini_translator_template',
        'openai_translator_template',
      ]) {
        expect(SettingsRepository.builtInSystemPromptFor(id),
            contains('{{target_language}}'));
      }
    });

    test('returns null for unknown or custom template ids', () {
      expect(SettingsRepository.builtInSystemPromptFor('nope'), isNull);
      expect(
        SettingsRepository.builtInSystemPromptFor('1730000000000'),
        isNull,
        reason: 'user-created templates use timestamps as ids',
      );
    });
  });
}
