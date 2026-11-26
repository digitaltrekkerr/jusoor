import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:markdown_renderer/markdown_renderer.dart';

import 'package:translation_app/l10n/app_localizations.dart';

/// Copies [text] as plain text (markdown stripped) and shows homeCopiedToClipboard.
void copyTranslationText(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: toPlainText(text)));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(AppLocalizations.of(context).homeCopiedToClipboard),
      duration: const Duration(seconds: 1),
    ),
  );
}

/// Bottom sheet: copy as plain text / copy as raw Markdown (long-press path).
Future<void> showCopyOptions(BuildContext context, String text) async {
  final l10n = AppLocalizations.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.copyOptionsTitle,
              style: Theme.of(sheetCtx).textTheme.titleMedium,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.short_text),
            title: Text(l10n.copyAsPlain),
            subtitle: Text(l10n.sheetPlainSubtitle),
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              await Clipboard.setData(
                ClipboardData(text: toPlainText(text)),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.homeCopiedToClipboard),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.copyAsMarkdown),
            subtitle: Text(l10n.sheetCopyMarkdownSubtitle),
            onTap: () async {
              Navigator.of(sheetCtx).pop();
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.homeCopiedToClipboard),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
