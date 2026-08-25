import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('ResponsePathExtractor', () {
    test('extracts value from standard OpenAI path', () {
      final json = <String, dynamic>{
        'choices': <Map<String, dynamic>>[
          {
            'message': {'content': 'Hello, world!'},
            'index': 0,
          },
        ],
        'model': 'gpt-4',
      };

      final result = ResponsePathExtractor.extract(
        json,
        'choices.0.message.content',
      );
      expect(result, 'Hello, world!');
    });

    test('extracts value from custom path', () {
      final json = <String, dynamic>{
        'result': {'translation': 'Hola mundo'},
      };

      final result = ResponsePathExtractor.extract(json, 'result.translation');
      expect(result, 'Hola mundo');
    });

    test('throws ResponsePathException for invalid path', () {
      final json = <String, dynamic>{
        'choices': <Map<String, dynamic>>[
          {
            'message': {'content': 'Hello'},
          },
        ],
      };

      expect(
        () => ResponsePathExtractor.extract(json, 'choices.0.nonexistent'),
        throwsA(isA<ResponsePathException>()),
      );
    });

    test('extracts value from nested path with multiple array indices', () {
      final json = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          {
            'items': <Map<String, dynamic>>[
              {'value': 'first'},
              {'value': 'second'},
            ],
          },
          {
            'items': <Map<String, dynamic>>[
              {'value': 'third'},
            ],
          },
        ],
      };

      final result = ResponsePathExtractor.extract(
        json,
        'data.0.items.1.value',
      );
      expect(result, 'second');
    });

    test('throws ResponsePathException for out-of-range index', () {
      final json = <String, dynamic>{
        'choices': <Map<String, dynamic>>[
          {
            'message': {'content': 'Hello'},
          },
        ],
      };

      expect(
        () => ResponsePathExtractor.extract(json, 'choices.5.message.content'),
        throwsA(isA<ResponsePathException>()),
      );
    });

    test(
      'throws ResponsePathException when non-list segment encounters list',
      () {
        final json = <String, dynamic>{
          'choices': <Map<String, dynamic>>[
            {
              'message': {'content': 'Hello'},
            },
          ],
        };

        expect(
          () => ResponsePathExtractor.extract(json, 'choices.0.0'),
          throwsA(isA<ResponsePathException>()),
        );
      },
    );

    test('throws ResponsePathException when key not found in map', () {
      final json = <String, dynamic>{
        'result': {'translation': 'Hola'},
      };

      expect(
        () => ResponsePathExtractor.extract(json, 'result.missing_key'),
        throwsA(isA<ResponsePathException>()),
      );
    });

    test('extracts integer value as string', () {
      final json = <String, dynamic>{
        'usage': {'total_tokens': 42},
      };

      final result = ResponsePathExtractor.extract(json, 'usage.total_tokens');
      expect(result, '42');
    });
  });
}
