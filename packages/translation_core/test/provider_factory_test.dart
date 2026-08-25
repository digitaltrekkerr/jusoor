import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/models/provider_profile.dart';
import 'package:translation_core/src/models/provider_type.dart';
import 'package:translation_core/src/providers/gemini_provider.dart';
import 'package:translation_core/src/providers/provider_factory.dart';

void main() {
  group('ProviderFactory', () {
    test('creates GeminiProvider with visionModel from profile', () {
      const profile = ProviderProfile(
        id: 'test-id',
        name: 'Test Gemini',
        providerType: ProviderType.gemini,
        model: 'gemini-2.5-flash',
        visionModel: 'gemini-2.5-pro',
      );

      final provider = ProviderFactory.create(
        profile: profile,
        apiKeyValue: 'test-key',
      );

      expect(provider, isA<GeminiProvider>());
      final geminiProvider = provider as GeminiProvider;
      expect(geminiProvider.model, 'gemini-2.5-flash');
      expect(geminiProvider.visionModel, 'gemini-2.5-pro');
      expect(geminiProvider.apiKey, 'test-key');
    });

    test(
      'creates GeminiProvider without visionModel when profile has none',
      () {
        const profile = ProviderProfile(
          id: 'test-id',
          name: 'Test Gemini',
          providerType: ProviderType.gemini,
          model: 'gemini-2.5-flash',
        );

        final provider = ProviderFactory.create(
          profile: profile,
          apiKeyValue: 'test-key',
        );

        expect(provider, isA<GeminiProvider>());
        final geminiProvider = provider as GeminiProvider;
        expect(geminiProvider.model, 'gemini-2.5-flash');
        expect(geminiProvider.visionModel, isNull);
      },
    );
  });
}
