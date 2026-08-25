import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('ProviderProfile', () {
    final openrouterProfile = ProviderProfile(
      id: 'id-1',
      name: 'OpenRouter Default',
      providerType: ProviderType.openrouter,
      apiKeyId: 'key-1',
      model: 'openai/gpt-4o',
      isBuiltIn: true,
    );

    final geminiProfile = ProviderProfile(
      id: 'id-2',
      name: 'Gemini Flash',
      providerType: ProviderType.gemini,
      apiKeyId: 'key-2',
      model: 'gemini-2.5-flash',
      visionModel: 'gemini-2.5-flash',
    );

    final openaiProfile = ProviderProfile(
      id: 'id-3',
      name: 'Local Ollama',
      providerType: ProviderType.openaiCompatible,
      apiKeyId: 'key-3',
      model: 'llama3',
      baseUrl: 'http://localhost:11434/v1',
    );

    group('constructor', () {
      test('isBuiltIn defaults to false', () {
        final profile = ProviderProfile(
          id: 'id',
          name: 'Test',
          providerType: ProviderType.openrouter,
          model: 'model',
        );
        expect(profile.isBuiltIn, isFalse);
      });

      test('stores all fields correctly', () {
        expect(openaiProfile.id, 'id-3');
        expect(openaiProfile.name, 'Local Ollama');
        expect(openaiProfile.providerType, ProviderType.openaiCompatible);
        expect(openaiProfile.apiKeyId, 'key-3');
        expect(openaiProfile.model, 'llama3');
        expect(openaiProfile.baseUrl, 'http://localhost:11434/v1');
      });

      test('nullable fields default to null', () {
        expect(openrouterProfile.fallbackApiKeyId, isNull);
        expect(openrouterProfile.visionModel, isNull);
        expect(openrouterProfile.baseUrl, isNull);
      });
    });

    group('equality', () {
      test('identical profiles are equal', () {
        final other = ProviderProfile(
          id: 'id-1',
          name: 'OpenRouter Default',
          providerType: ProviderType.openrouter,
          apiKeyId: 'key-1',
          model: 'openai/gpt-4o',
          isBuiltIn: true,
        );
        expect(openrouterProfile, equals(other));
      });

      test('profiles with different fields are not equal', () {
        expect(openrouterProfile, isNot(equals(geminiProfile)));
      });

      test('different isBuiltIn values are not equal', () {
        final builtIn = openrouterProfile;
        final notBuiltIn = openrouterProfile.copyWith(isBuiltIn: false);
        expect(builtIn, isNot(equals(notBuiltIn)));
      });
    });

    group('copyWith', () {
      test('copies with new name', () {
        final copy = openrouterProfile.copyWith(name: 'Renamed');
        expect(copy.name, 'Renamed');
        expect(copy.id, openrouterProfile.id);
        expect(copy.providerType, openrouterProfile.providerType);
        expect(copy.model, openrouterProfile.model);
      });

      test('copies with new model and visionModel', () {
        final copy = geminiProfile.copyWith(
          model: 'gemini-2.5-pro',
          visionModel: 'gemini-2.5-pro',
        );
        expect(copy.model, 'gemini-2.5-pro');
        expect(copy.visionModel, 'gemini-2.5-pro');
        expect(copy.id, geminiProfile.id);
      });

      test('original is unchanged after copyWith', () {
        final originalModel = openrouterProfile.model;
        openrouterProfile.copyWith(model: 'different');
        expect(openrouterProfile.model, originalModel);
      });
    });

    group('fromJson', () {
      test('parses a full OpenRouter profile', () {
        final json = {
          'id': 'id-1',
          'name': 'OpenRouter Default',
          'providerType': 'openrouter',
          'apiKeyId': 'key-1',
          'fallbackApiKeyId': null,
          'model': 'openai/gpt-4o',
          'visionModel': null,
          'baseUrl': null,
          'isBuiltIn': true,
        };
        final profile = ProviderProfile.fromJson(json);
        expect(profile, equals(openrouterProfile));
      });

      test('parses an OpenAI-Compatible profile', () {
        final json = {
          'id': 'id-3',
          'name': 'Local Ollama',
          'providerType': 'openai_compatible',
          'apiKeyId': 'key-3',
          'fallbackApiKeyId': null,
          'model': 'llama3',
          'visionModel': null,
          'baseUrl': 'http://localhost:11434/v1',
          'isBuiltIn': false,
        };
        final profile = ProviderProfile.fromJson(json);
        expect(profile, equals(openaiProfile));
      });

      test('ignores legacy fields bodyTemplate/customHeaders/responsePath', () {
        final json = {
          'id': 'id-3',
          'name': 'Local Ollama',
          'providerType': 'openai_compatible',
          'apiKeyId': 'key-3',
          'model': 'llama3',
          'baseUrl': 'http://localhost:11434/v1',
          'bodyTemplate': '{"model":"{{model}}"}',
          'customHeaders': {'X-Custom': 'value'},
          'responsePath': 'choices.0.message.content',
        };
        final profile = ProviderProfile.fromJson(json);
        expect(profile.id, 'id-3');
        expect(profile.model, 'llama3');
        expect(profile.baseUrl, 'http://localhost:11434/v1');
      });

      test('handles missing nullable fields gracefully', () {
        final json = {
          'id': 'id-1',
          'name': 'Minimal',
          'providerType': 'openrouter',
          'model': 'openai/gpt-4o',
        };
        final profile = ProviderProfile.fromJson(json);
        expect(profile.apiKeyId, isNull);
        expect(profile.fallbackApiKeyId, isNull);
        expect(profile.visionModel, isNull);
        expect(profile.baseUrl, isNull);
        expect(profile.isBuiltIn, isFalse);
      });

      test('handles empty map with safe defaults', () {
        final profile = ProviderProfile.fromJson({});
        expect(profile.id, '');
        expect(profile.name, '');
        expect(profile.providerType, ProviderType.openrouter);
        expect(profile.model, '');
        expect(profile.isBuiltIn, isFalse);
      });
    });

    group('toJson', () {
      test('serializes an OpenRouter profile correctly', () {
        final json = openrouterProfile.toJson();
        expect(json['id'], 'id-1');
        expect(json['name'], 'OpenRouter Default');
        expect(json['providerType'], 'openrouter');
        expect(json['apiKeyId'], 'key-1');
        expect(json['model'], 'openai/gpt-4o');
        expect(json['isBuiltIn'], isTrue);
        expect(json['visionModel'], isNull);
        expect(json['baseUrl'], isNull);
      });
    });

    group('round-trip', () {
      test('fromJson(toJson(x)) returns original for OpenRouter profile', () {
        final roundTripped = ProviderProfile.fromJson(
          openrouterProfile.toJson(),
        );
        expect(roundTripped, equals(openrouterProfile));
      });

      test('fromJson(toJson(x)) returns original for Gemini profile', () {
        final roundTripped = ProviderProfile.fromJson(geminiProfile.toJson());
        expect(roundTripped, equals(geminiProfile));
      });

      test(
        'fromJson(toJson(x)) returns original for OpenAI-Compatible profile',
        () {
          final roundTripped = ProviderProfile.fromJson(openaiProfile.toJson());
          expect(roundTripped, equals(openaiProfile));
        },
      );
    });
  });
}
