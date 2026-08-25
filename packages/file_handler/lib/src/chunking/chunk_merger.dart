/// Merges text chunks back into a single string.
///
/// Chunks are joined with double newlines (`\n\n`) to preserve
/// paragraph-level separation that was used during chunking.
class ChunkMerger {
  /// Merges [chunks] into a single string, joining each chunk with `\n\n`.
  static String merge(List<String> chunks) {
    return chunks.join('\n\n');
  }
}
