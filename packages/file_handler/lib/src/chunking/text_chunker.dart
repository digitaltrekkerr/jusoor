/// Splits text into chunks that respect paragraph and sentence boundaries,
/// targeting a maximum estimated token count per chunk.
///
/// Token estimation uses the heuristic `words * 1.3`. The chunker first
/// splits on paragraph boundaries (`\n\n`). When a single paragraph
/// exceeds the token limit, it is further split on sentence boundaries.
/// If a single sentence (or text with no sentence boundaries) still exceeds
/// the limit, a word-level fallback is used.
class TextChunker {
  /// Maximum estimated tokens per chunk.
  final int maxChunkTokens;

  /// Multiplier applied to word count to estimate tokens.
  static const double _tokenMultiplier = 1.3;

  /// Regex pattern for splitting on sentence boundaries.
  static final RegExp _sentencePattern = RegExp(r'(?<=[.!?])\s+');

  /// Creates a [TextChunker] with the given [maxChunkTokens].
  ///
  /// Defaults to 3000 tokens per chunk.
  const TextChunker({this.maxChunkTokens = 3000});

  /// Splits [text] into chunks that do not exceed [maxChunkTokens] estimated
  /// tokens.
  ///
  /// - If the text is small enough, returns a single-element list.
  /// - An empty string returns a list containing one empty string.
  List<String> chunk(String text) {
    if (text.isEmpty) return [''];

    final estimatedTokens = _estimateTokens(text);
    if (estimatedTokens <= maxChunkTokens) return [text];

    // Split into paragraphs first.
    final paragraphs = _splitParagraphs(text);
    final chunks = <String>[];
    var currentChunk = StringBuffer();

    for (final paragraph in paragraphs) {
      final paragraphTokens = _estimateTokens(paragraph);

      // If the paragraph itself exceeds the limit, flush current chunk
      // and split the paragraph into sentences.
      if (paragraphTokens > maxChunkTokens) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.toString().trim());
          currentChunk = StringBuffer();
        }
        _addSentenceChunks(paragraph, chunks);
        continue;
      }

      // Check if adding this paragraph would exceed the limit.
      final combinedText = currentChunk.isEmpty
          ? paragraph
          : '$currentChunk\n\n$paragraph';
      if (_estimateTokens(combinedText) > maxChunkTokens) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.toString().trim());
        }
        currentChunk = StringBuffer(paragraph);
      } else {
        if (currentChunk.isNotEmpty) {
          currentChunk.write('\n\n');
        }
        currentChunk.write(paragraph);
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trim());
    }

    return chunks;
  }

  /// Splits a large [paragraph] into sentence-based chunks and adds them
  /// to [chunks].
  void _addSentenceChunks(String paragraph, List<String> chunks) {
    final sentences = _splitSentences(paragraph);
    var currentChunk = StringBuffer();

    for (final sentence in sentences) {
      final sentenceTokens = _estimateTokens(sentence);

      // If a single sentence still exceeds the limit, split on word
      // boundaries as a fallback.
      if (sentenceTokens > maxChunkTokens) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.toString().trim());
          currentChunk = StringBuffer();
        }
        _addWordChunks(sentence, chunks);
        continue;
      }

      final combinedText = currentChunk.isEmpty
          ? sentence
          : '$currentChunk $sentence';

      if (_estimateTokens(combinedText) > maxChunkTokens &&
          currentChunk.isNotEmpty) {
        chunks.add(currentChunk.toString().trim());
        currentChunk = StringBuffer(sentence);
      } else {
        if (currentChunk.isNotEmpty) {
          currentChunk.write(' ');
        }
        currentChunk.write(sentence);
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trim());
    }
  }

  /// Fallback that splits a [sentence] (or text segment with no sentence
  /// boundaries) on word boundaries and adds resulting chunks to [chunks].
  void _addWordChunks(String sentence, List<String> chunks) {
    final words = sentence
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return;

    // Determine how many words fit in maxChunkTokens.
    final maxWordsPerChunk = (maxChunkTokens / _tokenMultiplier).floor();

    var i = 0;
    while (i < words.length) {
      final end = (i + maxWordsPerChunk).clamp(0, words.length);
      chunks.add(words.sublist(i, end).join(' '));
      i = end;
    }
  }

  /// Estimates the number of tokens in [text] using `words * 1.3`.
  int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return (wordCount * _tokenMultiplier).ceil();
  }

  /// Splits [text] into paragraphs on double-newline boundaries.
  List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Splits [text] into sentences using punctuation followed by whitespace.
  List<String> _splitSentences(String text) {
    final parts = text.split(_sentencePattern);
    return parts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}
