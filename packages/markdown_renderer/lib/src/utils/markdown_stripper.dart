import 'package:strip_markdown/strip_markdown.dart';

/// Strips Markdown formatting from a string, leaving plain text suitable for
/// clipboard copy, share text, and PDF body content.
///
/// Wraps `removeMd` from the `strip_markdown` package (a Dart port of
/// the popular Node.js `remove-markdown`). A second `*`-emphasis pass removes
/// markers that nested constructs (e.g. `**bold *italic* text**`) leave
/// behind after the first pass. Finally the result is trimmed and runs of
/// internal whitespace are collapsed to single spaces so the output reads as
/// natural prose.
///
/// This function is the single source of truth for clipboard plain-text
/// output. The Android overlay mirrors it in
/// `stripMarkdownForClipboard` (TranslationOverlayService.kt) — keep
/// the two in sync if either side is extended.
///
/// Example:
/// ```dart
/// toPlainText('# Hello **world**'); // => 'Hello world'
/// toPlainText('[link](https://x.com)'); // => 'link'
/// ```
String toPlainText(String markdown) {
  final stripped = removeMd(markdown);
  // Second `*`-emphasis pass: nested constructs such as
  // `**bold *italic* text**` survive the first pass with their inner
  // markers intact (`bold *italic* text`) and are only fully resolved
  // when the same rule is applied again.
  final nestedStripped = stripped.replaceAllMapped(
    RegExp(r'([\*]+)(\S)(.*?\S)??\1'),
    (match) => '${match.group(2) ?? ''}${match.group(3) ?? ''}',
  );
  return nestedStripped.replaceAll(RegExp(r'\s+'), ' ').trim();
}