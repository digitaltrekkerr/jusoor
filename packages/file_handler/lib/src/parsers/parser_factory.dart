import 'html_parser.dart';
import 'markdown_parser.dart';
import 'plain_text_parser.dart';

/// Factory that returns the appropriate parser for a given file extension.
///
/// Supported extensions:
/// - `.html` / `.htm` → [HtmlParser]
/// - `.md` / `.markdown` → [MarkdownParser]
/// - `.txt` / any other → [PlainTextParser]
class ParserFactory {
  /// Returns the correct parser instance for the given [extension].
  ///
  /// [extension] should be the file extension without a leading dot
  /// (e.g. `"html"`, `"md"`). The comparison is case-insensitive.
  static Object getParser(String extension) {
    switch (extension.toLowerCase()) {
      case 'html':
      case 'htm':
        return HtmlParser();
      case 'md':
      case 'markdown':
        return MarkdownParser();
      default:
        return PlainTextParser();
    }
  }

  /// Convenience method that selects the parser for [extension] and parses
  /// [content] in one call.
  ///
  /// Returns the parsed content as a [String].
  static String parse(String content, String extension) {
    final parser = getParser(extension);
    if (parser is HtmlParser) return parser.parse(content);
    if (parser is MarkdownParser) return parser.parse(content);
    if (parser is PlainTextParser) return parser.parse(content);
    // This should never happen, but satisfies the analyzer.
    return content;
  }
}
