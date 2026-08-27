import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:history/history.dart';
import 'package:markdown_renderer/markdown_renderer.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../services/deferred_temp_file_cleanup.dart';
import '../widgets/bidi_markdown_view.dart';
import 'package:share_plus/share_plus.dart';

/// Detail screen for a single translation record.
///
/// Shows the full input text, the rendered Markdown output, a copy button
/// (short-press = plain, long-press = choose Markdown), and a share button
/// that opens a bottom sheet with three options: plain text, Markdown
/// file, or save to a user-chosen location.
class HistoryDetailScreen extends StatelessWidget {
  /// The translation record to display.
  final TranslationRecord record;

  /// Creates the [HistoryDetailScreen].
  const HistoryDetailScreen({super.key, required this.record});

  // ── Copy ──────────────────────────────────────────────────────────────

  /// Copies the translation output as plain text (Markdown stripped).
  ///
  /// This is the safe default: pasting into another app or chat should not
  /// leak raw Markdown markers like `**` or `#` into the user's text.
  void _copyText(BuildContext context) {
    Clipboard.setData(
      ClipboardData(text: toPlainText(record.outputText)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).homeCopiedToClipboard),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Shows a bottom sheet letting the user pick between plain text and
  /// raw Markdown for the copy action.
  Future<void> _showCopyOptions(BuildContext context) async {
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
                  ClipboardData(text: toPlainText(record.outputText)),
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
                await Clipboard.setData(
                  ClipboardData(text: record.outputText),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Share ─────────────────────────────────────────────────────────────

  /// Opens a bottom sheet with three share options: plain text, Markdown
  /// file, or save-to-file via the system share sheet.
  Future<void> _showShareOptions(BuildContext context) async {
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
                l10n.shareOptionsTitle,
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: Text(l10n.shareAsPlain),
              subtitle: Text(l10n.sheetPlainSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await SharePlus.instance.share(
                  ShareParams(text: toPlainText(record.outputText)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.shareAsMarkdown),
              subtitle: Text(l10n.sheetMarkdownFileSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _shareAsMarkdown(l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.saveToFile),
              subtitle: Text(l10n.sheetSaveToFileSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _saveToDownloads(l10n);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Writes the translation output to a temporary `.md` file and opens
  /// the system share sheet.
  ///
  /// Preserved from the original single-mode share behaviour.
  Future<void> _shareAsMarkdown(AppLocalizations l10n) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/translation_${record.id}.md');
    try {
      await file.writeAsString(record.outputText);
      await SharePlus.instance.share(
        ShareParams(
          text: l10n.homeShareText,
          subject: l10n.homeShareSubject,
          files: [XFile(file.path)],
        ),
      );
    } finally {
      // Deferred cleanup: the share target may still be reading this file
      // after the sheet closes — deleting here races the receiving app.
      DeferredTempFileCleanup.instance.scheduleDeletion(file.path);
    }
  }

  /// Writes the translation output to a `.md` file in the temp directory
  /// and opens the share sheet with the file attached so the user can
  /// pick the final destination (Downloads, Drive, Telegram, etc.) without
  /// the app requiring `WRITE_EXTERNAL_STORAGE`.
  Future<void> _saveToDownloads(AppLocalizations l10n) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/jusoor_translation_${record.id}.md',
    );
    try {
      await file.writeAsString(record.outputText);
      await SharePlus.instance.share(
        ShareParams(
          text: l10n.homeShareText,
          subject: l10n.homeShareSubject,
          files: [XFile(file.path)],
        ),
      );
    } finally {
      // Deferred cleanup: keeps the file alive while the share target reads
      // it, then removes it after a grace period.
      DeferredTempFileCleanup.instance.scheduleDeletion(file.path);
    }
  }

  // ── Date formatting ─────────────────────────────────────────────────

  /// Formats a Unix-millisecond timestamp into a human-readable date string.
  static String _formatFullDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyDetailTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: l10n.homeCopyTooltip,
            onPressed: () => _copyText(context),
            onLongPress: () => _showCopyOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.homeShareTooltip,
            onPressed: () => _showShareOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: model & date ──────────────────────────────────
            _DetailHeader(
              modelUsed: record.modelUsed,
              date: _formatFullDate(record.createdAt),
              targetLanguage: record.targetLanguage,
              sourceLanguage: record.sourceLanguage,
              inputType: record.inputType,
              wordCount: record.wordCount,
              fileName: record.fileName,
            ),
            const SizedBox(height: 16),

            // ── Input text ────────────────────────────────────────────
            Text(l10n.historyInputLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    record.inputText,
                    style: theme.textTheme.bodyMedium,
                    textDirection: BiDiMarkdownView.isRtl(record.inputText)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Output (rendered Markdown) ─────────────────────────────
            Text(l10n.historyOutputLabel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: BiDiMarkdownView(markdownText: record.outputText),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Detail header ──────────────────────────────────────────────────────

/// Displays metadata about a translation record: model, date, languages,
/// word count, and file name.
class _DetailHeader extends StatelessWidget {
  final String modelUsed;
  final String date;
  final String targetLanguage;
  final String? sourceLanguage;
  final String inputType;
  final int? wordCount;
  final String? fileName;

  /// Creates the header.
  const _DetailHeader({
    required this.modelUsed,
    required this.date,
    required this.targetLanguage,
    required this.sourceLanguage,
    required this.inputType,
    required this.wordCount,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Model and date
            Row(
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    modelUsed,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Languages
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _MetadataChip(
                  icon: Icons.translate,
                  label: '${l10n.historyAutoDetected} → $targetLanguage',
                ),
                _MetadataChip(
                  icon: _inputTypeIcon(inputType),
                  label: inputType.capitalize(),
                ),
                if (wordCount != null)
                  _MetadataChip(
                    icon: Icons.text_fields,
                    label: l10n.homeWordCount(wordCount!),
                  ),
                if (fileName != null)
                  _MetadataChip(
                    icon: Icons.insert_drive_file,
                    // Isolate the filename so Arabic/mixed names don't
                    // scramble against the surrounding chip content.
                    label: '\u2066${fileName!}\u2069',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the appropriate icon for a given [inputType].
  static IconData _inputTypeIcon(String inputType) {
    return switch (inputType) {
      'file' => Icons.insert_drive_file,
      'image' => Icons.image,
      'screenshot' => Icons.screenshot,
      _ => Icons.text_fields,
    };
  }
}

// ── Metadata chip ──────────────────────────────────────────────────────

/// A small chip displaying an icon and a label, used in the detail header.
class _MetadataChip extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Creates the chip.
  const _MetadataChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RawChip(
      avatar: Icon(icon, size: 16),
      label: Text(label, style: theme.textTheme.bodySmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ── String extension ───────────────────────────────────────────────────

/// Extension on [String] for capitalizing the first letter.
extension StringCapExtension on String {
  /// Capitalizes the first character of this string.
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
