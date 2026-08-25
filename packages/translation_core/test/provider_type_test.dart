import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('ProviderType', () {
    group('fromJson', () {
      test('parses openai_compatible', () {
        expect(
          ProviderType.fromJson('openai_compatible'),
          ProviderType.openaiCompatible,
        );
      });

      test('parses gemini', () {
        expect(ProviderType.fromJson('gemini'), ProviderType.gemini);
      });

      test('parses openrouter', () {
        expect(ProviderType.fromJson('openrouter'), ProviderType.openrouter);
      });

      test('throws ArgumentError for unknown value', () {
        expect(() => ProviderType.fromJson('unknown'), throwsArgumentError);
      });
    });

    group('toJson', () {
      test('serializes openaiCompatible', () {
        expect(ProviderType.openaiCompatible.toJson(), 'openai_compatible');
      });

      test('serializes gemini', () {
        expect(ProviderType.gemini.toJson(), 'gemini');
      });

      test('serializes openrouter', () {
        expect(ProviderType.openrouter.toJson(), 'openrouter');
      });
    });

    group('displayName', () {
      test('returns correct display name for openaiCompatible', () {
        expect(ProviderType.openaiCompatible.displayName, 'OpenAI-Compatible');
      });

      test('returns correct display name for gemini', () {
        expect(ProviderType.gemini.displayName, 'Gemini');
      });

      test('returns correct display name for openrouter', () {
        expect(ProviderType.openrouter.displayName, 'OpenRouter');
      });
    });

    group('round-trip', () {
      test('fromJson(toJson(x)) returns original for all values', () {
        for (final type in ProviderType.values) {
          expect(ProviderType.fromJson(type.toJson()), type);
        }
      });
    });
  });
}
