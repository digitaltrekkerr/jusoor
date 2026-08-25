import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Instructions screen — single scrollable page with two sections:
/// 1. How to use the app
/// 2. How to write good prompts
///
/// Strings come from [AppLocalizations] with the `pages*` ARB key prefix.
class InstructionsScreen extends StatelessWidget {
  /// Creates the [InstructionsScreen].
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pagesInstructionsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionHeader(
              title: l10n.pagesHowToUseHeader,
              icon: Icons.tips_and_updates_outlined,
            ),
            const SizedBox(height: 8),
            _InstructionsCard(
              items: [
                l10n.pagesHowToUseStep1,
                l10n.pagesHowToUseStep2,
                l10n.pagesHowToUseStep3,
                l10n.pagesHowToUseStep4,
                l10n.pagesHowToUseStep5,
              ],
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: l10n.pagesHowToWritePromptsHeader,
              icon: Icons.edit_note_outlined,
            ),
            const SizedBox(height: 8),
            _InstructionsCard(
              items: [
                l10n.pagesHowToWritePromptsTip1,
                l10n.pagesHowToWritePromptsTip2,
                l10n.pagesHowToWritePromptsTip3,
                l10n.pagesHowToWritePromptsTip4,
                l10n.pagesHowToWritePromptsTip5,
                l10n.pagesHowToWritePromptsTip6,
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header used by [InstructionsScreen] — primary-tinted icon plus
/// a title. Renders correctly in RTL.
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card containing a numbered/bulleted list of instructions.
class _InstructionsCard extends StatelessWidget {
  final List<String> items;

  const _InstructionsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++)
              _InstructionRow(index: i + 1, text: items[i]),
          ],
        ),
      ),
    );
  }
}

class _InstructionRow extends StatelessWidget {
  final int index;
  final String text;

  const _InstructionRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '$index',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
