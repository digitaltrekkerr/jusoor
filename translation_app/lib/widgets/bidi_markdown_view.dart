import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class BiDiMarkdownView extends StatefulWidget {
  final String markdownText;
  final bool isLoading;
  final bool selectable;

  const BiDiMarkdownView({
    super.key,
    required this.markdownText,
    this.isLoading = false,
    this.selectable = false,
  });

  const BiDiMarkdownView.loading({super.key})
      : markdownText = '',
        isLoading = true,
        selectable = false,
        super();

  const BiDiMarkdownView.streaming({super.key, required String partial, this.selectable = false})
      : markdownText = partial,
        isLoading = false,
        super();

  static TextDirection detectDirection(
    String text, {
    TextDirection fallback = TextDirection.ltr,
    TextDirection? previous,
  }) {
    // Strip non-prose content first: link targets, bare URLs, and code
    // (fenced + inline) are almost always Latin script and would otherwise
    // skew the RTL/LTR ratio of documents written in Arabic or other RTL
    // languages. Only the leading window needs to be examined — direction is
    // decided by the dominant script, which the beginning of the text reveals.
    final sourceText = text.length > _maxDirectionScanRunes
        ? String.fromCharCodes(text.runes.take(_maxDirectionScanRunes))
        : text;
    final clean = sourceText
        .replaceAll(_codeFencePattern, ' ')
        .replaceAll(_inlineCodePattern, ' ')
        .replaceAll(_linkTargetPattern, ']()')
        .replaceAll(_bareUrlPattern, '')
        .replaceAll(_markdownSymbolsPattern, '');
    if (clean.isEmpty) return fallback;

    int rtlCount = 0;
    int ltrCount = 0;

    for (final rune in clean.runes) {
      if (_isRtlRune(rune)) {
        rtlCount++;
      } else if (_isLtrRune(rune)) {
        ltrCount++;
      }
    }

    if (rtlCount == 0 && ltrCount == 0) return fallback;

    final total = rtlCount + ltrCount;
    final rtlRatio = rtlCount / total;

    if (previous != null) {
      if (previous == TextDirection.rtl && rtlRatio >= 0.45) {
        return TextDirection.rtl;
      }
      if (previous == TextDirection.ltr && rtlRatio <= 0.55) {
        return TextDirection.ltr;
      }
    }

    return rtlRatio >= 0.55 ? TextDirection.rtl : TextDirection.ltr;
  }

  static bool isRtl(String text) => detectDirection(text) == TextDirection.rtl;

  @override
  State<BiDiMarkdownView> createState() => _BiDiMarkdownViewState();
}

bool _isRtlRune(int rune) {
  return (rune >= 0x0590 && rune <= 0x05FF) || // Hebrew
         (rune >= 0x0600 && rune <= 0x06FF) || // Arabic
         (rune >= 0x0700 && rune <= 0x074F) || // Syriac
         (rune >= 0x0750 && rune <= 0x077F) || // Arabic Supplement
         (rune >= 0x0780 && rune <= 0x07BF) || // Thaana
         (rune >= 0x07C0 && rune <= 0x07FF) || // NKo
         (rune >= 0x0800 && rune <= 0x083F) || // Samaritan
         (rune >= 0x0840 && rune <= 0x085F) || // Mandaic
         (rune >= 0x0860 && rune <= 0x086F) || // Syriac Supplement
         (rune >= 0x0870 && rune <= 0x089F) || // Arabic Extended-B
         (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic Extended-A
         (rune >= 0xFB1D && rune <= 0xFDFF) || // Hebrew/Arabic Presentation Forms
         (rune >= 0xFE70 && rune <= 0xFEFF) || // Arabic Presentation Forms-B
         (rune >= 0x1E800 && rune <= 0x1EDFF) || // Mende Kikakui / Adlam
         (rune >= 0x1EE00 && rune <= 0x1EEFF);   // Arabic Mathematical
}

bool _isLtrRune(int rune) {
  return (rune >= 0x0041 && rune <= 0x005A) || // A-Z
         (rune >= 0x0061 && rune <= 0x007A) || // a-z
         (rune >= 0x00C0 && rune <= 0x024F) || // Latin Supplement + Extended
         (rune >= 0x1E00 && rune <= 0x1EFF) || // Latin Extended Additional
         (rune >= 0x2C60 && rune <= 0x2C7F) || // Latin Extended-C
         (rune >= 0xA720 && rune <= 0xA7FF) || // Latin Extended-D
         (rune >= 0xAB30 && rune <= 0xAB6F);    // Latin Extended-E
}

// Reused across calls: direction detection runs on every keystroke and every
// streaming update, so we must not rebuild these patterns on each call.
final RegExp _codeFencePattern = RegExp(r'```[\s\S]*?```');
final RegExp _inlineCodePattern = RegExp(r'`[^`\n]*`');
final RegExp _linkTargetPattern = RegExp(r'\]\([^)]*\)');
final RegExp _bareUrlPattern = RegExp(r'https?://\S+');
final RegExp _markdownSymbolsPattern = RegExp(r'[*_~`#>|\[\]\(\)-]');

/// Maximum number of code points scanned to detect text direction.
///
/// Direction is determined by the dominant script, which the start of a
/// document reveals. Capping the window keeps detection O(window) instead of
/// O(document) when streaming a long translation or editing a large file.
const int _maxDirectionScanRunes = 8000;

class _BiDiMarkdownViewState extends State<BiDiMarkdownView> {
  TextDirection? _detectedDirection;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(BiDiMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.markdownText != oldWidget.markdownText) {
      _syncDirection();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_detectedDirection == null) {
      _detectedDirection = BiDiMarkdownView.detectDirection(
        widget.markdownText,
        fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    } else {
      _syncDirection();
    }
  }

  void _syncDirection() {
    final newDir = BiDiMarkdownView.detectDirection(
      widget.markdownText,
      fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      previous: _detectedDirection,
    );
    if (newDir != _detectedDirection) {
      setState(() { _detectedDirection = newDir; });
    }
  }

  Future<void> _onTapLink(String text, String? href, String title) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  MarkdownStyleSheet _buildStyleSheet(
    BuildContext context,
    TextDirection direction,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentSide = BorderSide(color: colorScheme.primary, width: 4);

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      h1: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ) ??
          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      h2: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ) ??
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      h3: theme.textTheme.titleMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ) ??
          const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: colorScheme.surfaceContainerHighest,
        color: colorScheme.onSurface,
      ),
      codeblockPadding: const EdgeInsets.all(16),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      a: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      blockquote: TextStyle(
        fontStyle: FontStyle.italic,
        color: colorScheme.onSurfaceVariant,
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        // Accent bar sits on the reading-start side of the quote.
        border: direction == TextDirection.rtl
            ? Border(right: accentSide)
            : Border(left: accentSide),
      ),
      tableBorder: TableBorder.all(
        color: colorScheme.outlineVariant,
        width: 1,
        borderRadius: BorderRadius.circular(4),
      ),
      tableHeadCellsPadding: const EdgeInsets.all(12),
      tableCellsPadding: const EdgeInsets.all(12),
      tableHeadCellsDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
      ),
      listBullet: TextStyle(color: colorScheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final direction = _detectedDirection ?? Directionality.maybeOf(context) ?? TextDirection.ltr;

    final styleSheet = _buildStyleSheet(context, direction);

    final markdownBody = MarkdownBody(
      // Keep the direction in the key (layout changes) but drop the text
      // length: re-keying on every streamed chunk would discard the whole
      // subtree and rebuild the selection machinery from scratch each time.
      key: ValueKey('md-$direction'),
      data: widget.markdownText,
      styleSheet: styleSheet,
      builders: {
        // Fenced code blocks are code: force LTR base direction so mixed
        // Latin/symbol content inside an RTL document keeps its logical order.
        'pre': _LtrCodeBlockBuilder(
          codeStyle: styleSheet.code ??
              const TextStyle(fontFamily: 'monospace', fontSize: 14),
          background: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: styleSheet.codeblockPadding ?? const EdgeInsets.all(16),
        ),
      },
      onTapLink: _onTapLink,
      shrinkWrap: true,
      fitContent: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
    );

    return Directionality(
      key: ValueKey('bidi-dir-$direction'),
      textDirection: direction,
      child: widget.selectable
          ? SelectionArea(child: markdownBody)
          : markdownBody,
    );
  }
}

/// Renders fenced code blocks with a forced LTR base direction.
///
/// Replicates the default `pre` rendering (code style, background, horizontal
/// scrolling) while insulating code content from the ambient RTL context.
/// The scrollbar is intentionally omitted: it would require one scroll
/// controller per block; touch dragging still scrolls horizontally.
class _LtrCodeBlockBuilder extends MarkdownElementBuilder {
  _LtrCodeBlockBuilder({
    required this.codeStyle,
    required this.background,
    this.padding = const EdgeInsets.all(16),
  });

  final TextStyle codeStyle;
  final Color background;
  final EdgeInsetsGeometry padding;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(text.text, style: codeStyle),
        ),
      ),
    );
  }
}
