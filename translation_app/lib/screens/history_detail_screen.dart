import 'dart:io';

import 'package:flutter/material.dart';
import 'package:history/history.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/bidi_markdown_view.dart';
import 'package:share_plus/share_plus.dart';

/// Detail screen for a single translation record.
///
/// Shows the full input text, the rendered Markdown output, and a share
/// button that exports the output as a temporary `.md` file.
class HistoryDetailScreen extends StatelessWidget {
  /// The translation record to display.
  final TranslationRecord record;

  /// Creates the [HistoryDetailScreen].
  const HistoryDetailScreen({super.key, required this.record});

  // ── Share ─────────────────────────────────────────────────────────────

  /// Exports the translation output as a temporary `.md` file and invokes
  /// the system share sheet.
  ///
  /// The temp file is deleted after sharing to avoid leaving artefacts on
  /// permanent storage.
  Future<void> _handleShare() async {
    final tempDir = await getTemporaryDirectory();
    // Record IDs are always set when loaded from the database.
    final file = File(
      '${tempDir.path}/translation_${record.id}.md',
    ); // ignore: null_check_on_fail
    try {
      await file.writeAsString(record.outputText);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Translation result',
          subject: 'Jusoor Result',
          files: [XFile(file.path)],
        ),
      );
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share translation',
            onPressed: _handleShare,
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
            Text('Input', style: theme.textTheme.titleMedium),
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
            Text('Output', style: theme.textTheme.titleMedium),
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
                  label: 'Auto-detected → $targetLanguage',
                ),
                _MetadataChip(
                  icon: _inputTypeIcon(inputType),
                  label: inputType.capitalize(),
                ),
                if (wordCount != null)
                  _MetadataChip(
                    icon: Icons.text_fields,
                    label: '$wordCount words',
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
