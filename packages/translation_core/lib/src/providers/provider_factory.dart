import '../models/provider_profile.dart';
import '../models/provider_type.dart';
import '../models/translation_provider.dart';
import 'gemini_provider.dart';
import 'openai_compatible_provider.dart';
import 'openrouter_provider.dart';

/// Factory that creates the appropriate [TranslationProvider] based on the
/// supplied configuration.
///
/// The entry point is [create], which takes a [ProviderProfile] and API key
/// value.
class ProviderFactory {
  ProviderFactory._();

  /// Creates a [TranslationProvider] from a [ProviderProfile] and API key.
  ///
  /// Selects the concrete provider implementation based on
  /// [ProviderProfile.providerType] and forwards the relevant profile fields.
  static TranslationProvider create({
    required ProviderProfile profile,
    required String apiKeyValue,
  }) {
    switch (profile.providerType) {
      case ProviderType.openrouter:
        return OpenRouterProvider.fromProfile(
          profile: profile,
          apiKey: apiKeyValue,
        );
      case ProviderType.gemini:
        return GeminiProvider(
          apiKey: apiKeyValue,
          model: profile.model,
          visionModel: profile.visionModel,
        );
      case ProviderType.openaiCompatible:
        return OpenAICompatibleProvider(
          apiKey: apiKeyValue,
          baseUrl: profile.baseUrl ?? 'https://api.openai.com/v1',
          model: profile.model,
          visionModel: profile.visionModel,
        );
    }
  }
}
