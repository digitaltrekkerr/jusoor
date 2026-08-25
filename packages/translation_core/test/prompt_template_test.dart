import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('PromptTemplate', () {
    final textTemplate = PromptTemplate(
      id: 'tpl-1',
      profileId: 'profile-1',
      name: 'Professional Translator',
      systemPrompt:
          'You are a professional translator. Translate to {{target_language}}.',
      supportsText: true,
      supportsImage: false,
      isBuiltIn: true,
    );

    final imageTemplate = PromptTemplate(
      id: 'tpl-2',
      profileId: 'profile-1',
      name: 'Image Translator',
      systemPrompt: 'Translate the text in the image to {{target_language}}.',
      supportsText: false,
      supportsImage: true,
    );

    group('constructor', () {
      test('isBuiltIn defaults to false', () {
        final template = PromptTemplate(
          id: 'id',
          profileId: 'pid',
          name: 'Test',
          systemPrompt: 'prompt',
          supportsText: true,
          supportsImage: false,
        );
        expect(template.isBuiltIn, isFalse);
      });

      test('substituteTargetLanguage defaults to true', () {
        final template = PromptTemplate(
          id: 'id',
          profileId: 'pid',
          name: 'Test',
          systemPrompt: 'prompt',
          supportsText: true,
          supportsImage: false,
        );
        expect(template.substituteTargetLanguage, isTrue);
      });

      test('stores all fields correctly', () {
        expect(textTemplate.id, 'tpl-1');
        expect(textTemplate.profileId, 'profile-1');
        expect(textTemplate.name, 'Professional Translator');
        expect(textTemplate.systemPrompt, contains('professional translator'));
        expect(textTemplate.supportsText, isTrue);
        expect(textTemplate.supportsImage, isFalse);
        expect(textTemplate.isBuiltIn, isTrue);
        expect(textTemplate.substituteTargetLanguage, isTrue);
      });
    });

    group('equality', () {
      test('identical templates are equal', () {
        final other = PromptTemplate(
          id: 'tpl-1',
          profileId: 'profile-1',
          name: 'Professional Translator',
          systemPrompt:
              'You are a professional translator. Translate to {{target_language}}.',
          supportsText: true,
          supportsImage: false,
          isBuiltIn: true,
        );
        expect(textTemplate, equals(other));
      });

      test('templates with different fields are not equal', () {
        expect(textTemplate, isNot(equals(imageTemplate)));
      });

      test('different isBuiltIn values are not equal', () {
        final copy = textTemplate.copyWith(isBuiltIn: false);
        expect(textTemplate, isNot(equals(copy)));
      });
    });

    group('copyWith', () {
      test('copies with new name', () {
        final copy = textTemplate.copyWith(name: 'Casual Translator');
        expect(copy.name, 'Casual Translator');
        expect(copy.id, textTemplate.id);
        expect(copy.profileId, textTemplate.profileId);
        expect(copy.systemPrompt, textTemplate.systemPrompt);
      });

      test('copies with new systemPrompt', () {
        final copy = textTemplate.copyWith(
          systemPrompt: 'New prompt for {{target_language}}.',
        );
        expect(copy.systemPrompt, 'New prompt for {{target_language}}.');
      });

      test('original is unchanged after copyWith', () {
        final originalName = textTemplate.name;
        textTemplate.copyWith(name: 'Different');
        expect(textTemplate.name, originalName);
      });

      test('copies with new substituteTargetLanguage', () {
        final copy = textTemplate.copyWith(substituteTargetLanguage: false);
        expect(copy.substituteTargetLanguage, isFalse);
        expect(textTemplate.substituteTargetLanguage, isTrue);
      });
    });

    group('fromJson', () {
      test('parses a full template', () {
        final json = {
          'id': 'tpl-1',
          'profileId': 'profile-1',
          'name': 'Professional Translator',
          'systemPrompt':
              'You are a professional translator. Translate to {{target_language}}.',
          'supportsText': true,
          'supportsImage': false,
          'isBuiltIn': true,
        };
        final template = PromptTemplate.fromJson(json);
        expect(template, equals(textTemplate));
      });

      test('handles missing fields with safe defaults', () {
        final json = <String, dynamic>{};
        final template = PromptTemplate.fromJson(json);
        expect(template.id, '');
        expect(template.profileId, '');
        expect(template.name, '');
        expect(template.systemPrompt, '');
        expect(template.supportsText, isTrue);
        expect(template.supportsImage, isFalse);
        expect(template.isBuiltIn, isFalse);
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'tpl-2',
          'profileId': 'profile-1',
          'name': 'Image Translator',
          'systemPrompt':
              'Translate the text in the image to {{target_language}}.',
          'supportsText': false,
          'supportsImage': true,
          'isBuiltIn': null,
        };
        final template = PromptTemplate.fromJson(json);
        expect(template.isBuiltIn, isFalse);
      });

      test('substituteTargetLanguage defaults to true when missing', () {
        final json = {
          'id': 'tpl-3',
          'profileId': 'profile-1',
          'name': 'Missing Flag',
          'systemPrompt': 'Prompt',
          'supportsText': true,
          'supportsImage': false,
        };
        final template = PromptTemplate.fromJson(json);
        expect(template.substituteTargetLanguage, isTrue);
      });

      test('parses substituteTargetLanguage: false from JSON', () {
        final json = {
          'id': 'tpl-4',
          'profileId': 'profile-1',
          'name': 'Literal Mode',
          'systemPrompt': 'Prompt {{target_language}}',
          'supportsText': true,
          'supportsImage': false,
          'substituteTargetLanguage': false,
        };
        final template = PromptTemplate.fromJson(json);
        expect(template.substituteTargetLanguage, isFalse);
      });
    });

    group('toJson', () {
      test('serializes a template correctly', () {
        final json = textTemplate.toJson();
        expect(json['id'], 'tpl-1');
        expect(json['profileId'], 'profile-1');
        expect(json['name'], 'Professional Translator');
        expect(json['systemPrompt'], contains('professional translator'));
        expect(json['supportsText'], isTrue);
        expect(json['supportsImage'], isFalse);
        expect(json['isBuiltIn'], isTrue);
        expect(json['substituteTargetLanguage'], isTrue);
      });

      test('serializes substituteTargetLanguage: false', () {
        final template = textTemplate.copyWith(substituteTargetLanguage: false);
        final json = template.toJson();
        expect(json['substituteTargetLanguage'], isFalse);
      });
    });

    group('round-trip', () {
      test('fromJson(toJson(x)) returns original for text template', () {
        final roundTripped = PromptTemplate.fromJson(textTemplate.toJson());
        expect(roundTripped, equals(textTemplate));
      });

      test('fromJson(toJson(x)) returns original for image template', () {
        final roundTripped = PromptTemplate.fromJson(imageTemplate.toJson());
        expect(roundTripped, equals(imageTemplate));
      });
    });
  });
}
