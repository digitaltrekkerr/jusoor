import 'package:file_handler/file_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChunkMerger', () {
    test('merges multiple chunks with double newline', () {
      const chunks = ['Chunk 1', 'Chunk 2', 'Chunk 3'];
      final result = ChunkMerger.merge(chunks);
      expect(result, equals('Chunk 1\n\nChunk 2\n\nChunk 3'));
    });

    test('merges single chunk without extra newlines', () {
      const chunks = ['Only chunk'];
      final result = ChunkMerger.merge(chunks);
      expect(result, equals('Only chunk'));
    });

    test('merges empty list to empty string', () {
      const chunks = <String>[];
      final result = ChunkMerger.merge(chunks);
      expect(result, equals(''));
    });

    test('merges chunks with empty strings', () {
      const chunks = ['A', '', 'B'];
      final result = ChunkMerger.merge(chunks);
      expect(result, equals('A\n\n\n\nB'));
    });
  });
}
