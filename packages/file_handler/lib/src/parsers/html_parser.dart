import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Converts an HTML string into clean Markdown.
///
/// Handles headings, paragraphs, lists, tables, blockquotes, code blocks,
/// inline formatting (bold, italic, links), and line breaks. Strips
/// `script`, `style`, `nav`, and `footer` elements entirely.
class HtmlParser {
  /// HTML tag names whose content should be completely stripped.
  static const _strippedTags = {'script', 'style', 'nav', 'footer'};

  /// Parses [htmlString] and returns a Markdown representation.
  String parse(String htmlString) {
    final document = html_parser.parse(htmlString);
    final body = document.body;
    if (body == null) return '';
    return _processNode(body).trim();
  }

  /// Recursively processes a DOM [node] and returns its Markdown string.
  String _processNode(dom.Node node) {
    // Text node — return its text content directly.
    if (node.nodeType == dom.Node.TEXT_NODE) {
      return node.text ?? '';
    }

    // Only Element nodes have a localName.
    if (node.nodeType != dom.Node.ELEMENT_NODE) {
      // Process children for non-element nodes (e.g. Document).
      return _processChildren(node);
    }

    final element = node as dom.Element;
    final tag = element.localName ?? '';

    // Strip unwanted elements entirely.
    if (_strippedTags.contains(tag)) return '';

    // Process children first so we can wrap their output.
    final childContent = _processChildren(element);
    final trimmedContent = childContent.trim();

    switch (tag) {
      // Headings h1–h6
      case 'h1':
        return '# $trimmedContent\n\n';
      case 'h2':
        return '## $trimmedContent\n\n';
      case 'h3':
        return '### $trimmedContent\n\n';
      case 'h4':
        return '#### $trimmedContent\n\n';
      case 'h5':
        return '##### $trimmedContent\n\n';
      case 'h6':
        return '###### $trimmedContent\n\n';

      // Paragraph
      case 'p':
        return '$trimmedContent\n\n';

      // Line break
      case 'br':
        return '\n';

      // List items
      case 'li':
        return '- $trimmedContent\n';

      // Unordered / ordered lists — just render children (li handles bullets)
      case 'ul':
      case 'ol':
        return childContent;

      // Tables
      case 'table':
        return _convertTable(element);

      // Blockquote
      case 'blockquote':
        final lines = trimmedContent.split('\n');
        final quoted = lines.map((l) => '> $l').join('\n');
        return '$quoted\n\n';

      // Preformatted / code block
      case 'pre':
        return '```\n$trimmedContent\n```\n\n';

      // Inline bold
      case 'strong':
      case 'b':
        return '**$trimmedContent**';

      // Inline italic
      case 'em':
      case 'i':
        return '*$trimmedContent*';

      // Anchor / link
      case 'a':
        final href = element.attributes['href'] ?? '';
        if (href.isNotEmpty) {
          return '[$trimmedContent]($href)';
        }
        return trimmedContent;

      // For other elements, just return processed children.
      default:
        return childContent;
    }
  }

  /// Processes all child nodes of [parent] and concatenates their output.
  String _processChildren(dom.Node parent) {
    final buffer = StringBuffer();
    for (final child in parent.nodes) {
      buffer.write(_processNode(child));
    }
    return buffer.toString();
  }

  /// Converts a `<table>` element to pipe-delimited Markdown.
  String _convertTable(dom.Element table) {
    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) return '';

    final buffer = StringBuffer();
    var rowIndex = 0;

    for (final row in rows) {
      final cells = row.querySelectorAll('td, th');
      final cellTexts = cells.map((cell) {
        return _processNode(cell).trim();
      }).toList();

      buffer.write('| ');
      buffer.write(cellTexts.join(' | '));
      buffer.write(' |\n');

      // Add separator after the first row (header row)
      if (rowIndex == 0) {
        buffer.write('| ');
        buffer.write(List.filled(cellTexts.length, '---').join(' | '));
        buffer.write(' |\n');
      }

      rowIndex++;
    }

    return buffer.toString();
  }
}
