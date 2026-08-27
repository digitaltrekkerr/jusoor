import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_renderer/markdown_renderer.dart';

void main() {
  group('isAllowedMarkdownLinkScheme', () {
    test('https is allowed', () {
      expect(isAllowedMarkdownLinkScheme('https'), isTrue);
    });

    test('http is allowed', () {
      expect(isAllowedMarkdownLinkScheme('http'), isTrue);
    });

    test('mailto is allowed', () {
      expect(isAllowedMarkdownLinkScheme('mailto'), isTrue);
    });

    test('intent scheme is denied', () {
      expect(isAllowedMarkdownLinkScheme('intent'), isFalse);
    });

    test('custom app schemes are denied', () {
      expect(isAllowedMarkdownLinkScheme('figma'), isFalse);
      expect(isAllowedMarkdownLinkScheme('geo'), isFalse);
      expect(isAllowedMarkdownLinkScheme('tel'), isFalse);
    });

    test('file scheme is denied (app never loads local file links)', () {
      expect(isAllowedMarkdownLinkScheme('file'), isFalse);
    });

    test('empty scheme is denied', () {
      expect(isAllowedMarkdownLinkScheme(''), isFalse);
    });

    test('uppercase variants are handled case-insensitively', () {
      expect(isAllowedMarkdownLinkScheme('HTTPS'), isTrue);
      expect(isAllowedMarkdownLinkScheme('HTTP'), isTrue);
      expect(isAllowedMarkdownLinkScheme('MailTo'), isTrue);
      expect(isAllowedMarkdownLinkScheme('INTENT'), isFalse);
    });
  });
}