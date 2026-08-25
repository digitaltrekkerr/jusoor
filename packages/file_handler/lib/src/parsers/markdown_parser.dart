/// A parser for Markdown content that returns the input string as-is.
///
/// Performs light validation: if the content has no Markdown-like formatting
/// at all (no headings, lists, emphasis, or links), it is likely plain text,
/// but is still returned unchanged — the caller can inspect [isLikelyMarkdown]
/// if needed.
class MarkdownParser {
  /// Parses [content] and returns it unchanged.
  ///
  /// The optional [isLikelyMarkdown] flag in the return value indicates
  /// whether the content appears to contain Markdown formatting.
  String parse(String content) {
    return content;
  }

  /// Returns `true` if [content] appears to contain Markdown formatting
  /// such as headings, emphasis, lists, or links.
  bool isLikelyMarkdown(String content) {
    // Headings: # at start of line
    if (RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(content)) return true;
    // Emphasis: **text** or *text*
    if (RegExp(r'\*\*.+?\*\*').hasMatch(content)) return true;
    if (RegExp(
      r'(?<!\*)\*(?!\*).+?(?<!\*)\*(?!\*)',
      dotAll: true,
    ).hasMatch(content)) {
      return true;
    }
    // Unordered list: - or * at start of line
    if (RegExp(r'^[\-\*]\s', multiLine: true).hasMatch(content)) {
      return true;
    }
    // Links: [text](url)
    if (RegExp(r'\[.+?\]\(.+?\)').hasMatch(content)) return true;
    // Code blocks
    if (content.contains('```')) return true;

    return false;
  }
}
