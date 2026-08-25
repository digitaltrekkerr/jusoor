import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('VariableSubstitutor', () {
    late TranslationRequest baseRequest;

    setUp(() {
      baseRequest = const TranslationRequest(
        inputText: 'Hello world',
        targetLanguage: 'Spanish',
        imageBase64: 'base64data==',
        wordCount: 2,
        systemPrompt: 'You are a helpful translator.',
        model: 'openai/gpt-4o',
      );
    });

    test('substitutes system_prompt', () {
      final result = VariableSubstitutor.substitute(
        '{{system_prompt}}',
        baseRequest,
      );
      expect(result, 'You are a helpful translator.');
    });

    test('substitutes input_text', () {
      final result = VariableSubstitutor.substitute(
        '{{input_text}}',
        baseRequest,
      );
      expect(result, 'Hello world');
    });

    test('substitutes target_language', () {
      final result = VariableSubstitutor.substitute(
        '{{target_language}}',
        baseRequest,
      );
      expect(result, 'Spanish');
    });

    test('resolves source_language to empty string for auto-detect requests', () {
      final result = VariableSubstitutor.substitute(
        '{{source_language}}',
        baseRequest,
      );
      expect(result, '');
    });

    test('substitutes image_base64 when present', () {
      final result = VariableSubstitutor.substitute(
        '{{image_base64}}',
        baseRequest,
      );
      expect(result, 'base64data==');
    });

    test('substitutes image_base64 with empty string when null', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'Spanish',
      );
      final result = VariableSubstitutor.substitute(
        '{{image_base64}}',
        request,
      );
      expect(result, '');
    });

    test('substitutes image_mime_type when present', () {
      final result = VariableSubstitutor.substitute(
        '{{image_mime_type}}',
        baseRequest,
      );
      expect(result, 'image/jpeg');
    });

    test('substitutes image_mime_type with custom value', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'Spanish',
        imageBase64: 'data==',
        imageMimeType: 'image/png',
      );
      final result = VariableSubstitutor.substitute(
        '{{image_mime_type}}',
        request,
      );
      expect(result, 'image/png');
    });

    test('substitutes image_mime_type with default when null', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'Spanish',
      );
      final result = VariableSubstitutor.substitute(
        '{{image_mime_type}}',
        request,
      );
      expect(result, 'image/jpeg');
    });

    test('substitutes model', () {
      final result = VariableSubstitutor.substitute('{{model}}', baseRequest);
      expect(result, 'openai/gpt-4o');
    });

    test('substitutes word_count', () {
      final result = VariableSubstitutor.substitute(
        '{{word_count}}',
        baseRequest,
      );
      expect(result, '2');
    });

    test('replaces unknown variable with empty string', () {
      final result = VariableSubstitutor.substitute(
        '{{unknown_var}}',
        baseRequest,
      );
      expect(result, '');
    });

    test('substitute maps api_key to empty string, not model', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'Spanish',
        model: 'gpt-4o',
      );
      final result = VariableSubstitutor.substitute(
        'key: {{api_key}}',
        request,
      );
      expect(result, 'key: ');
    });

    test('substitutes multiple variables in one template', () {
      final result = VariableSubstitutor.substitute(
        'Model: {{model}}, Text: {{input_text}}, Target: {{target_language}}',
        baseRequest,
      );
      expect(
        result,
        'Model: openai/gpt-4o, Text: Hello world, Target: Spanish',
      );
    });

    test('substitutes all 9 variables at once', () {
      final result = VariableSubstitutor.substitute(
        '{{system_prompt}}|{{input_text}}|{{target_language}}|{{source_language}}|{{image_base64}}|{{image_mime_type}}|{{api_key}}|{{model}}|{{word_count}}',
        baseRequest,
      );
      expect(result.contains('You are a helpful translator.'), isTrue);
      expect(result.contains('Hello world'), isTrue);
      expect(result.contains('Spanish'), isTrue);
      expect(result.contains('base64data=='), isTrue);
      expect(result.contains('image/jpeg'), isTrue);
      expect(result.contains('openai/gpt-4o'), isTrue);
      expect(result.contains('2'), isTrue);
    });
  });

  group('VariableSubstitutor.buildVariableMap', () {
    test('uses supplied apiKey for api_key variable', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'Spanish',
      );
      final map = VariableSubstitutor.buildVariableMap(
        request,
        'my-secret-key',
      );
      expect(map['api_key'], 'my-secret-key');
    });
  });

  group('VariableSubstitutor with substituteTargetLanguage flag', () {
    late TranslationRequest baseRequest;

    setUp(() {
      baseRequest = const TranslationRequest(
        inputText: 'Hello world',
        targetLanguage: 'Spanish',
        systemPrompt: 'You are a helpful translator.',
        model: 'openai/gpt-4o',
      );
    });

    test('default request keeps target_language substitution enabled', () {
      // Default (no override) should behave exactly like the legacy code
      // and replace {{target_language}} with the actual language name.
      final result = VariableSubstitutor.substitute(
        'Translate to {{target_language}}.',
        baseRequest,
      );
      expect(result, 'Translate to Spanish.');
    });

    test('substituteTargetLanguage: true replaces target_language', () {
      const request = TranslationRequest(
        inputText: 'Hello world',
        targetLanguage: 'French',
        systemPrompt: 'You are a helpful translator.',
        model: 'openai/gpt-4o',
        substituteTargetLanguage: true,
      );
      final result = VariableSubstitutor.substitute(
        'Translate to {{target_language}}.',
        request,
      );
      expect(result, 'Translate to French.');
    });

    test('substituteTargetLanguage: false leaves {{target_language}} literal', () {
      const request = TranslationRequest(
        inputText: 'Hello world',
        targetLanguage: 'French',
        systemPrompt: 'You are a helpful translator.',
        model: 'openai/gpt-4o',
        substituteTargetLanguage: false,
      );
      final result = VariableSubstitutor.substitute(
        'Translate to {{target_language}}.',
        request,
      );
      expect(result, 'Translate to {{target_language}}.');
    });

    test('only target_language is kept literal — other placeholders still resolve', () {
      const request = TranslationRequest(
        inputText: 'Hello world',
        targetLanguage: 'German',
        systemPrompt: 'You are a helpful translator.',
        model: 'openai/gpt-4o',
        substituteTargetLanguage: false,
      );
      final result = VariableSubstitutor.substitute(
        'Model: {{model}} | Text: {{input_text}} | Target: {{target_language}}',
        request,
      );
      expect(
        result,
        'Model: openai/gpt-4o | Text: Hello world | Target: {{target_language}}',
      );
    });

    test('substituteMap honors substituteTargetLanguage: false', () {
      const variables = <String, String>{
        'model': 'openai/gpt-4o',
        'input_text': 'Hello',
        'target_language': 'Italian',
      };
      final result = VariableSubstitutor.substituteMap(
        'Model: {{model}} | Target: {{target_language}}',
        variables,
        substituteTargetLanguage: false,
      );
      expect(
        result,
        'Model: openai/gpt-4o | Target: {{target_language}}',
      );
    });

    test('substituteMap default behavior still substitutes target_language', () {
      const variables = <String, String>{
        'model': 'openai/gpt-4o',
        'input_text': 'Hello',
        'target_language': 'Italian',
      };
      final result = VariableSubstitutor.substituteMap(
        'Model: {{model}} | Target: {{target_language}}',
        variables,
      );
      expect(result, 'Model: openai/gpt-4o | Target: Italian');
    });
  });

  group('VariableSubstitutor.buildRawVariableMap', () {
    test('does not JSON-escape string values', () {
      const request = TranslationRequest(
        inputText: 'Hello\nworld',
        targetLanguage: 'Spanish',
        systemPrompt: 'Translate to {{target_language}}.\nNew line.',
      );
      final map = VariableSubstitutor.buildRawVariableMap(request, 'key');

      expect(map['input_text'], 'Hello\nworld');
      expect(map['target_language'], 'Spanish');
      expect(
        map['system_prompt'],
        'Translate to {{target_language}}.\nNew line.',
      );
      expect(map['api_key'], 'key');
    });

    test('resolves nested placeholders in systemPrompt via substituteMap', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'French',
        systemPrompt:
            'Translate to {{target_language}}.',
      );
      final map = VariableSubstitutor.buildRawVariableMap(request);
      final resolved = VariableSubstitutor.substituteMap(
        request.systemPrompt,
        map,
      );
      expect(resolved, 'Translate to French.');
    });

    test('api_key defaults to empty string when not provided', () {
      const request = TranslationRequest(
        inputText: 'Hello',
        targetLanguage: 'Spanish',
      );
      final map = VariableSubstitutor.buildRawVariableMap(request);
      expect(map['api_key'], '');
    });
  });
}
