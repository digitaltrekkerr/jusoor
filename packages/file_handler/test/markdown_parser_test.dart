import 'package:file_handler/file_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarkdownParser', () {
    late MarkdownParser parser;

    setUp(() {
      parser = MarkdownParser();
    });

    test('returns markdown as-is', () {
      const markdown = '# Heading\n\nSome **bold** text.';
      final result = parser.parse(markdown);
      expect(result, equals(markdown));
    });

    test('returns plain text as-is', () {
      const text = 'This is just plain text with no formatting.';
      final result = parser.parse(text);
      expect(result, equals(text));
    });

    test('isLikelyMarkdown returns true for headings', () {
      expect(parser.isLikelyMarkdown('# Heading'), isTrue);
    });

    test('isLikelyMarkdown returns true for bold', () {
      expect(parser.isLikelyMarkdown('Some **bold** text'), isTrue);
    });

    test('isLikelyMarkdown returns true for links', () {
      expect(parser.isLikelyMarkdown('[Link](https://example.com)'), isTrue);
    });

    test('isLikelyMarkdown returns true for code blocks', () {
      expect(parser.isLikelyMarkdown('```\ncode\n```'), isTrue);
    });

    test('isLikelyMarkdown returns false for plain text', () {
      expect(
        parser.isLikelyMarkdown('This is just plain text with no formatting.'),
        isFalse,
      );
    });
  });
}
