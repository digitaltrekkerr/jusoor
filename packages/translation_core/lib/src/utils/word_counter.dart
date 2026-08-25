/// Counts words in text and checks against a limit.
class WordCounter {
  WordCounter._();

  /// Counts the number of words in [text] by splitting on whitespace and
  /// counting non-empty segments.
  static int count(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Returns `true` if [count] is within [limit] (inclusive).
  static bool isWithinLimit(int count, int limit) => count <= limit;
}
