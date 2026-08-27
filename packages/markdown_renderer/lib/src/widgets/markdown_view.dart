import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'markdown_view_helpers.dart';

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
  /// Delegates to [handleMarkdownLinkTap] so link-tap behavior stays
  /// in one place (shared with BiDiMarkdownView). [context] is the
  /// State's own context, used by the confirmation dialog.
  Future<void> _onTapLink(String text, String? href, String title) =>
      handleMarkdownLinkTap(context, href);

  /// Builds the [MarkdownStyleSheet] via the shared helper. See
  /// [buildBaseMarkdownStyleSheet] for the styling contract.
  MarkdownStyleSheet _buildStyleSheet(BuildContext context) =>
      buildBaseMarkdownStyleSheet(context);

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
