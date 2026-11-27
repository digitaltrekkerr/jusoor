import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_app/services/settings_repository.dart';

/// Minimal valid prompt templates payload (`prompt_templates` pref) holding a
/// single built-in template with the given prompt.
String _templatesJson(String id, String name, String prompt) =>
    '''
[{"id":"$id","profileId":"openrouter_default_profile","name":"$name",
"systemPrompt":${_jsonString(prompt)},"supportsText":true,
"supportsImage":true,"isBuiltIn":true}]
''';

String _jsonString(String raw) {
  final escaped = raw
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
  return '"$escaped"';
}

/// A prompt that the app shipped by default before revision 4.
final _legacyPrompt = SettingsRepository.legacyBuiltInPrompts.first;

Future<SettingsRepository> _repoWith({
  required Map<String, Object> prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  FlutterSecureStorage.setMockInitialValues({});
  return SettingsRepository(
    secureStorage: const FlutterSecureStorage(),
    prefs: sharedPrefs,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('built-ins revision 4 (default prompt upgrade)', () {
    test(
      'replaces an untouched legacy default with the shipped prompt',
      () async {
        final repo = await _repoWith(
          prefs: {
            'data_migrated_v2': true,
            'built_ins_revision': 3,
            'prompt_templates': _templatesJson(
              'gemini_translator_template',
              'Gemini Reconstruction Translator',
              _legacyPrompt,
            ),
          },
        );

        await repo.migrateToProfileSystem();

        expect(
          repo.getTemplate('gemini_translator_template')?.systemPrompt,
          SettingsRepository.systemPromptTemplate,
        );
      },
    );

    test('keeps a user-edited prompt exactly as it was', () async {
      const edited = 'Translate to {{target_language}}. Use my own rules.';
      final repo = await _repoWith(
        prefs: {
          'data_migrated_v2': true,
          'built_ins_revision': 3,
          'prompt_templates': _templatesJson(
            'gemini_translator_template',
            'Gemini Reconstruction Translator',
            edited,
          ),
        },
      );

      await repo.migrateToProfileSystem();

      expect(
        repo.getTemplate('gemini_translator_template')?.systemPrompt,
        edited,
      );
    });

    test('is idempotent — a second run changes nothing', () async {
      final repo = await _repoWith(
        prefs: {
          'data_migrated_v2': true,
          'built_ins_revision': 3,
          'prompt_templates': _templatesJson(
            'openai_translator_template',
            'OpenAI Translator',
            _legacyPrompt,
          ),
        },
      );

      await repo.migrateToProfileSystem();
      final shipped = repo.getTemplate('openai_translator_template');
      await repo.migrateToProfileSystem();

      expect(
        repo.getTemplate('openai_translator_template')?.systemPrompt,
        shipped?.systemPrompt,
      );
    });
  });
}
