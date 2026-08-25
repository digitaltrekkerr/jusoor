import 'package:file_handler/file_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlainTextParser', () {
    late PlainTextParser parser;

    setUp(() {
      parser = PlainTextParser();
    });

    test('returns text as-is', () {
      const text = 'Hello, world!';
      final result = parser.parse(text);
      expect(result, equals(text));
    });

    test('returns empty string as-is', () {
      const text = '';
      final result = parser.parse(text);
      expect(result, equals(text));
    });

    test('returns multiline text as-is', () {
      const text = 'Line 1\nLine 2\nLine 3';
      final result = parser.parse(text);
      expect(result, equals(text));
    });
  });
}
