import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that renders Markdown text with selectable text support,
/// custom theming, and streaming/loading states.
///
/// Uses [MarkdownBody] from flutter_markdown_plus with GitHub Flavored
/// Markdown (GFM) enabled by default for table, code block, and
/// strike-through support.
///
/// When [selectable] is `true`, the content is wrapped in a
/// [SelectionArea] for multi-line text selection on Android.
class MarkdownView extends StatefulWidget {
  /// The Markdown text to render.
  final String markdownText;

  /// Whether the rendered text should be selectable via long-press.
  ///
  /// Defaults to `true`. Uses [SelectionArea] wrapper for better
  /// multi-line selection on Android.
  final bool selectable;

  /// Creates a [MarkdownView] that renders the given [markdownText].
  const MarkdownView({
    super.key,
    required this.markdownText,
    this.selectable = true,
  }) : _isLoading = false;

  /// Creates a [MarkdownView] that shows a loading indicator
  /// while a translation is being processed.
  ///
  /// Displays a centered [CircularProgressIndicator] with a
  /// "Translating..." label.
  const MarkdownView.loading({super.key})
    : markdownText = '',
      selectable = false,
      _isLoading = true;

  /// Creates a [MarkdownView] for streaming translation output.
  ///
  /// The parent widget is responsible for updating [partial] as new
  /// chunks arrive. The widget re-renders on each update without
  /// flickering.
  const MarkdownView.streaming({super.key, required String partial})
    : markdownText = partial,
      selectable = true,
      _isLoading = false;

  /// Internal flag indicating the loading state.
  final bool _isLoading;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  /// Opens [href] in an external browser using [url_launcher].
  Future<void> _onTapLink(String text, String? href, String title) async {
    if (href == null) return;
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Builds the [MarkdownStyleSheet] based on the current theme with
  /// custom overrides for headings, code, links, blockquotes, tables,
  /// and lists.
  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      // Headings: explicit sizes per spec (h1=24, h2=22, h3=20)
      h1:
          theme.textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ) ??
          const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      h2:
          theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ) ??
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      h3:
          theme.textTheme.titleMedium?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ) ??
          const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),

      // Inline code: monospace font with light background
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        backgroundColor: colorScheme.surfaceContainerHighest,
        color: colorScheme.onSurface,
      ),

      // Code blocks: dark background, monospace, padding
      codeblockPadding: const EdgeInsets.all(16),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),

      // Links: themed primary color with underline
      a: TextStyle(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
      ),

      // Blockquotes: italic, left border accent
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
        border: Border(left: BorderSide(color: colorScheme.primary, width: 4)),
      ),

      // Tables: visible borders
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

      // Lists: themed bullet color
      listBullet: TextStyle(color: colorScheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state: show progress indicator
    if (widget._isLoading) {
      return const _LoadingIndicator();
    }

    final markdownBody = MarkdownBody(
      data: widget.markdownText,
      styleSheet: _buildStyleSheet(context),
      onTapLink: _onTapLink,
      shrinkWrap: true,
      fitContent: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
    );

    // Wrap in SelectionArea when selectable is true for multi-line
    // selection support on Android.
    if (widget.selectable) {
      return SelectionArea(child: markdownBody);
    }

    return markdownBody;
  }
}

/// A centered loading indicator displayed while a translation is
/// being processed.
///
/// Shows a [CircularProgressIndicator] with a "Translating..." label.
class _LoadingIndicator extends StatelessWidget {
  /// Creates the loading indicator.
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Translating...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
