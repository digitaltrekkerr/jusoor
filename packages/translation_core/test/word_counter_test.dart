import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('WordCounter', () {
    test('counts words in basic text', () {
      expect(WordCounter.count('Hello world'), 2);
    });

    test('returns 0 for empty string', () {
      expect(WordCounter.count(''), 0);
    });

    test('returns 0 for whitespace-only string', () {
      expect(WordCounter.count('   '), 0);
    });

    test('counts words separated by multiple spaces', () {
      expect(WordCounter.count('Hello   world   foo'), 3);
    });

    test('counts words with tabs and newlines', () {
      expect(WordCounter.count('Hello\tworld\nfoo'), 3);
    });

    test('counts single word', () {
      expect(WordCounter.count('Hello'), 1);
    });

    test('counts word with leading/trailing whitespace', () {
      expect(WordCounter.count('  Hello world  '), 2);
    });
  });

  group('WordCounter.isWithinLimit', () {
    test('returns true when count equals limit', () {
      expect(WordCounter.isWithinLimit(10, 10), isTrue);
    });

    test('returns true when count is below limit', () {
      expect(WordCounter.isWithinLimit(5, 10), isTrue);
    });

    test('returns false when count exceeds limit', () {
      expect(WordCounter.isWithinLimit(11, 10), isFalse);
    });

    test('returns true when count is zero', () {
      expect(WordCounter.isWithinLimit(0, 10), isTrue);
    });
  });
}
