import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Link schemes that may be opened automatically when the user taps a
/// rendered markdown link.
///
/// Markdown can come from untrusted imported/translated content, so any
/// scheme outside this allowlist (e.g. `intent:`, `geo:`, `tel:`, custom
/// app deep links) is silently ignored and never launched — launching them
/// could fire exported components of other apps (activity injection)
/// without any user confirmation. `file:` is intentionally excluded: the
/// app renders document text and never produces local `file://` links.
const Set<String> _allowedLinkSchemes = {'http', 'https', 'mailto'};

/// Returns true when [scheme] (matched case-insensitively) is on the
/// safe-to-launch allowlist. Empty and unknown schemes return false.
bool isAllowedMarkdownLinkScheme(String scheme) {
  return _allowedLinkSchemes.contains(scheme.toLowerCase());
}

/// Opens [href] in an external browser/app when its scheme is allowlisted.
/// Returns silently if [href] is null, malformed, un-launchable, carries a
/// non-allowlisted scheme, or if the user cancels the confirmation dialog.
///
/// Used by both [MarkdownView] and BiDiMarkdownView as their `onTapLink`
/// callback for [MarkdownBody]. `http(s)` links prompt the user with a
/// confirmation dialog before launching; `mailto:` links launch directly
/// (mail clients are safe targets). Every other scheme is dropped.
Future<void> handleMarkdownLinkTap(BuildContext context, String? href) async {
  if (href == null) return;
  final uri = Uri.tryParse(href);
  if (uri == null) return;

  // SECURITY: only allowlisted schemes may launch. See comment above.
  if (!isAllowedMarkdownLinkScheme(uri.scheme)) return;

  // Confirm external http(s) links before launching.
  if (uri.isScheme('http') || uri.isScheme('https')) {
    final confirmed = await _confirmExternalLink(context, uri);
    if (confirmed != true) return;
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Shows a confirmation dialog for an external [uri]. Returns `true`
/// only when the user explicitly taps "Open". Returns `false` on
/// Cancel and `null` if the dialog is dismissed without a choice.
Future<bool?> _confirmExternalLink(BuildContext context, Uri uri) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Open external link?'),
      content: Text(uri.host.isNotEmpty ? uri.host : uri.toString()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Open'),
        ),
      ],
    ),
  );
}

/// Builds the common MarkdownStyleSheet used by [MarkdownView] and
/// BiDiMarkdownView — headings, code, links, tables, lists, and the
/// blockquote accent decoration.
///
/// [blockquoteBorder] lets callers place the accent bar on the
/// reading-start side of the quote (left for LTR, right for RTL).
/// When null, defaults to a 4-px primary-color left border, matching
/// the pre-refactor [MarkdownView] behavior.
MarkdownStyleSheet buildBaseMarkdownStyleSheet(
  BuildContext context, {
  Border? blockquoteBorder,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
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
    blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    blockquoteDecoration: BoxDecoration(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(4),
      border:
          blockquoteBorder ??
          Border(left: BorderSide(color: colorScheme.primary, width: 4)),
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
