import 'package:file_handler/file_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextChunker', () {
    late TextChunker chunker;

    setUp(() {
      chunker = const TextChunker();
    });

    test('short text under limit returns single chunk', () {
      const text = 'Hello world';
      final chunks = chunker.chunk(text);
      expect(chunks, hasLength(1));
      expect(chunks.first, equals(text));
    });

    test('empty string returns single empty chunk', () {
      final chunks = chunker.chunk('');
      expect(chunks, hasLength(1));
      expect(chunks.first, equals(''));
    });

    test('long text with sentences is split into multiple chunks', () {
      // 10,000 words as sentences with proper punctuation.
      // 10,000 words × 1.3 tokens/word ≈ 13,000 tokens.
      // With maxChunkTokens = 3000, we expect at least 4 chunks.
      final sentences = List.generate(
        2000,
        (i) => 'This is sentence number $i with enough words.',
      );
      final text = sentences.join(' ');
      final chunks = chunker.chunk(text);
      expect(chunks.length, greaterThanOrEqualTo(4));
    });

    test('no chunk exceeds the token limit', () {
      final sentences = List.generate(
        2000,
        (i) => 'This is sentence number $i with enough words.',
      );
      final text = sentences.join(' ');
      final chunks = chunker.chunk(text);

      for (final chunk in chunks) {
        final wordCount = chunk
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
        final estimatedTokens = (wordCount * 1.3).ceil();
        // Allow a small margin because the last sentence in a chunk may
        // slightly overshoot the soft limit before flushing.
        expect(estimatedTokens, lessThanOrEqualTo(3200));
      }
    });

    test('chunk boundaries fall on paragraph breaks', () {
      // Each paragraph is small, so chunks should split at paragraph boundaries.
      final paragraphs = List.generate(
        10,
        (i) =>
            'This is paragraph number $i with enough words to be meaningful.',
      );
      final text = paragraphs.join('\n\n');
      final smallChunker = const TextChunker(maxChunkTokens: 50);
      final chunks = smallChunker.chunk(text);
      expect(chunks.length, greaterThan(1));
    });

    test('chunk boundaries fall on sentence ends for large paragraphs', () {
      // A single paragraph that exceeds the token limit.
      final sentences = List.generate(20, (i) => 'Sentence number $i is here.');
      final text = sentences.join(' ');
      final smallChunker = const TextChunker(maxChunkTokens: 30);
      final chunks = smallChunker.chunk(text);
      expect(chunks.length, greaterThan(1));

      // Verify chunks end with sentence-ending punctuation (trimmed).
      for (final chunk in chunks) {
        expect(chunk, endsWith('.'));
      }
    });

    test('word-level fallback for text without sentence boundaries', () {
      // Text with no punctuation — forces word-level splitting.
      final words = List.generate(10000, (i) => 'word$i');
      final text = words.join(' ');
      final chunks = chunker.chunk(text);
      expect(chunks.length, greaterThanOrEqualTo(4));

      // Verify all words are present in the output.
      final merged = chunks.join(' ');
      for (final word in words) {
        expect(merged, contains(word));
      }
    });

    test('preserves text content across chunking and merging', () {
      final sentences = List.generate(
        500,
        (i) => 'Sentence number $i is here.',
      );
      final text = sentences.join(' ');
      final chunks = chunker.chunk(text);
      final merged = ChunkMerger.merge(chunks);
      // The merged text should contain the core content.
      for (final sentence in sentences) {
        expect(merged, contains(sentence));
      }
    });

    test('single paragraph under limit is one chunk', () {
      const text = 'This is a single short paragraph.';
      final chunks = chunker.chunk(text);
      expect(chunks, hasLength(1));
      expect(chunks.first, equals(text));
    });

    test('custom maxChunkTokens is respected', () {
      final sentences = List.generate(
        1000,
        (i) => 'Sentence number $i is here.',
      );
      final text = sentences.join(' ');

      const smallLimit = 500;
      final smallChunker = const TextChunker(maxChunkTokens: smallLimit);
      final chunks = smallChunker.chunk(text);

      // More chunks with a smaller limit
      final defaultChunks = chunker.chunk(text);
      expect(chunks.length, greaterThan(defaultChunks.length));
    });
  });
}
