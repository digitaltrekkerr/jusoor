import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_renderer/markdown_renderer.dart';

void main() {
  group('toPlainText', () {
    test('strips bold markdown', () {
      expect(toPlainText('**hello**'), 'hello');
    });

    test('strips italic markdown', () {
      expect(toPlainText('*hello*'), 'hello');
      expect(toPlainText('_hello_'), 'hello');
    });

    test('strips headers', () {
      expect(toPlainText('# Title'), 'Title');
      expect(toPlainText('## Subtitle'), 'Subtitle');
    });

    test('strips links but keeps text', () {
      expect(toPlainText('[link](https://example.com)'), 'link');
    });

    test('keeps image alt text', () {
      expect(toPlainText('![alt](img.png)'), 'alt');
    });

    test('strips inline code backticks but keeps content', () {
      expect(toPlainText('use `print()` here'), 'use print() here');
    });

    test('strips multiple inline code spans', () {
      expect(toPlainText('`a` and `b` and `c`'), 'a and b and c');
    });

    test('strips markdown inside inline code spans', () {
      expect(toPlainText('nested `code **bold**` inline'), 'nested code bold inline');
    });

    test('strips fenced code blocks but keeps content (exact)', () {
      expect(
        toPlainText('```dart\nvoid main() {}\n```'),
        'void main() {}',
      );
    });

    test('keeps fenced content when fences sit between prose', () {
      expect(
        toPlainText('Before:\n```dart\nvoid main() {}\n```\nAfter.'),
        'Before: void main() {} After.',
      );
    });

    test('strips fenced blocks without a language hint', () {
      expect(
        toPlainText('```\nconsole.log("x")\n```'),
        'console.log("x")',
      );
    });

    test('strips backticks inside fenced code content', () {
      expect(toPlainText('```text\na `b` c\n```'), 'a b c');
    });

    test('strips emphasis markers inside fenced code content', () {
      expect(toPlainText('```text\n*a*\n```'), 'a');
    });

    test('strips triple-asterisk nested bold+italic', () {
      expect(toPlainText('***bold italic***'), 'bold italic');
    });

    test('strips bold wrapping italic (nested asterisks)', () {
      expect(toPlainText('**bold *italic* text**'), 'bold italic text');
    });

    test('strips bold wrapping italic (underscore inner)', () {
      expect(toPlainText('**bold _italic_ text**'), 'bold italic text');
    });

    test('strips italic wrapping bold (underscore outer)', () {
      expect(toPlainText('_nested **bold** inside_'), 'nested bold inside');
    });

    test('is idempotent for nested bold+italic', () {
      const input = '**bold *italic* text**';
      expect(toPlainText(toPlainText(input)), toPlainText(input));
    });

    test('keeps single asterisks in plain arithmetic text', () {
      expect(toPlainText('5 * 3'), '5 * 3');
    });

    test('does not treat word-internal underscores as emphasis', () {
      expect(toPlainText('a__b__c'), 'a__b__c');
      expect(toPlainText('a_b_c'), 'a_b_c');
    });

    test('collapses whitespace runs to single space', () {
      expect(toPlainText('a   b\n\nc'), 'a b c');
    });

    test('collapses plain newlines to single space', () {
      expect(toPlainText('line1\nline2'), 'line1 line2');
    });

    test('trims leading and trailing whitespace', () {
      expect(toPlainText('  hello  '), 'hello');
    });

    test('passes through plain text untouched', () {
      expect(toPlainText('Just plain text.'), 'Just plain text.');
    });

    test('handles list bullets and ordered lists', () {
      expect(toPlainText('- item\n- other'), 'item other');
      expect(toPlainText('1. first\n2. second'), 'first second');
    });

    test('strips blockquote markers', () {
      expect(toPlainText('> quote line'), 'quote line');
    });

    test('strips strikethrough', () {
      expect(toPlainText('~~strike~~'), 'strike');
    });

    test('handles Arabic markdown', () {
      expect(toPlainText('**مرحبا** بالعالم'), 'مرحبا بالعالم');
    });

    test('handles mixed inline constructs', () {
      expect(
        toPlainText('Text **with** nested `code` *inside*.'),
        'Text with nested code inside.',
      );
    });

    test('handles empty string', () {
      expect(toPlainText(''), '');
    });

    test('handles nested markdown in headers', () {
      expect(
        toPlainText('## **bold title**'),
        'bold title',
      );
    });
  });
}