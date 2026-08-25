import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/translation_core.dart';

void main() {
  group('SSEParser', () {
    late SSEParser parser;

    setUp(() {
      parser = SSEParser(responsePath: 'choices.0.delta.content');
    });

    test('parses data with space after colon (data: )', () {
      const chunk = 'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Hello']);
    });

    test('parses data without space after colon (data:)', () {
      const chunk = 'data:{"choices":[{"delta":{"content":"World"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['World']);
    });

    test('parses mixed formats in same stream', () {
      const chunk =
          'data: {"choices":[{"delta":{"content":"Hello"}}]}\n'
          'data:{"choices":[{"delta":{"content":" World"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Hello', ' World']);
    });

    test('skips [DONE] signal with space', () {
      const chunk =
          'data: {"choices":[{"delta":{"content":"Hi"}}]}\n'
          'data: [DONE]\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Hi']);
    });

    test('skips [DONE] signal without space', () {
      const chunk =
          'data:{"choices":[{"delta":{"content":"Hi"}}]}\n'
          'data:[DONE]\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Hi']);
    });

    test('skips non-data lines', () {
      const chunk =
          'event: message\n'
          'id: 123\n'
          'data: {"choices":[{"delta":{"content":"Ok"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Ok']);
    });

    test('skips empty data lines', () {
      const chunk =
          'data: \n'
          'data: {"choices":[{"delta":{"content":"Text"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Text']);
    });

    test('buffers incomplete line across chunks', () {
      // First chunk ends mid-line.
      final results1 = parser.parseChunk('data: {"choices":[{"delta":');
      expect(results1, isEmpty);

      // Second chunk completes the line.
      final results2 = parser.parseChunk('{"content":"Buffered"}}]}\n\n');
      expect(results2, ['Buffered']);
    });

    test('resets buffer on reset()', () {
      parser.parseChunk('data: {"choices":[{"delta":');
      parser.reset();

      // After reset, the buffered fragment is gone so the next chunk
      // should not produce output from the previous fragment.
      final results = parser.parseChunk('{"content":"Stale"}}]}\n\n');
      expect(results, isEmpty);
    });

    test('skips malformed JSON', () {
      const chunk =
          'data: not-json\n'
          'data: {"choices":[{"delta":{"content":"Good"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Good']);
    });

    test('skips events where response path is not found', () {
      // Role-only delta has no "content" field.
      const chunk =
          'data: {"choices":[{"delta":{"role":"assistant"}}]}\n'
          'data: {"choices":[{"delta":{"content":"Found"}}]}\n\n';
      final results = parser.parseChunk(chunk);

      expect(results, ['Found']);
    });

    test('uses custom response path for Gemini format without space', () {
      final geminiParser = SSEParser(
        responsePath: 'candidates.0.content.parts.0.text',
      );

      const chunk =
          'data:{"candidates":[{"content":{"parts":[{"text":"Gemini"}]}}]}\n\n';
      final results = geminiParser.parseChunk(chunk);

      expect(results, ['Gemini']);
    });
  });
}
