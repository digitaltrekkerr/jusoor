import 'package:file_handler/file_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ParserFactory', () {
    test('returns HtmlParser for .html extension', () {
      final parser = ParserFactory.getParser('html');
      expect(parser, isA<HtmlParser>());
    });

    test('returns HtmlParser for .htm extension', () {
      final parser = ParserFactory.getParser('htm');
      expect(parser, isA<HtmlParser>());
    });

    test('returns HtmlParser for uppercase HTML extension', () {
      final parser = ParserFactory.getParser('HTML');
      expect(parser, isA<HtmlParser>());
    });

    test('returns MarkdownParser for .md extension', () {
      final parser = ParserFactory.getParser('md');
      expect(parser, isA<MarkdownParser>());
    });

    test('returns MarkdownParser for .markdown extension', () {
      final parser = ParserFactory.getParser('markdown');
      expect(parser, isA<MarkdownParser>());
    });

    test('returns PlainTextParser for .txt extension', () {
      final parser = ParserFactory.getParser('txt');
      expect(parser, isA<PlainTextParser>());
    });

    test('returns PlainTextParser for unknown extension', () {
      final parser = ParserFactory.getParser('csv');
      expect(parser, isA<PlainTextParser>());
    });

    test('parse method delegates to HtmlParser for html', () {
      const html = '<h1>Hello</h1>';
      final result = ParserFactory.parse(html, 'html');
      expect(result, contains('# Hello'));
    });

    test('parse method delegates to MarkdownParser for md', () {
      const markdown = '# Heading';
      final result = ParserFactory.parse(markdown, 'md');
      expect(result, equals(markdown));
    });

    test('parse method delegates to PlainTextParser for txt', () {
      const text = 'Hello world';
      final result = ParserFactory.parse(text, 'txt');
      expect(result, equals(text));
    });
  });
}
