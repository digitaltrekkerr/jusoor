import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('buildTemplateRequest — V1 wire shape', () {
    const profile = ProviderProfile(
      id: 'p1',
      name: 'Test profile',
      providerType: ProviderType.openrouter,
      model: 'openai/gpt-4o',
    );

    test('profile fields populate the request', () {
      const template = PromptTemplate(
        id: 't1',
        profileId: 'p1',
        name: 'Basic template',
        systemPrompt: 'You are a translator.',
        supportsText: true,
        supportsImage: false,
      );

      final request = buildTemplateRequest(
        inputText: 'Hello',
        targetLanguage: 'Arabic',
        template: template,
        profile: profile,
      );

      expect(request.systemPrompt, template.systemPrompt);
      expect(request.model, profile.model);
      expect(request.profileId, profile.id);
      expect(
        request.substituteTargetLanguage,
        template.substituteTargetLanguage,
      );
    });

    test('override arguments win over template/profile defaults', () {
      const template = PromptTemplate(
        id: 't2',
        profileId: 'p1',
        name: 'Fallback-driven template',
        systemPrompt: 'Original prompt.',
        supportsText: true,
        supportsImage: false,
      );

      final request = buildTemplateRequest(
        inputText: 'Hello',
        targetLanguage: 'Arabic',
        template: template,
        profile: profile,
        model: 'fallback/model',
        systemPrompt: 'Fallback prompt.',
        profileId: 'fallback-profile',
      );

      expect(request.model, 'fallback/model');
      expect(request.systemPrompt, 'Fallback prompt.');
      expect(request.profileId, 'fallback-profile');
    });

    test('substituteTargetLanguage override is honored', () {
      const template = PromptTemplate(
        id: 't3',
        profileId: 'p1',
        name: 'No-substitute template',
        systemPrompt: 'Prompt with {{target_language}}.',
        supportsText: true,
        supportsImage: false,
        substituteTargetLanguage: true,
      );

      final request = buildTemplateRequest(
        inputText: 'Hello',
        targetLanguage: 'Arabic',
        template: template,
        profile: profile,
        substituteTargetLanguage: false,
      );

      expect(request.substituteTargetLanguage, isFalse);
    });
  });
}
