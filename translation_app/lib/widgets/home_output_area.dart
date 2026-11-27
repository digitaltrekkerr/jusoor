import 'package:flutter/material.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/widgets/bidi_markdown_view.dart';
import 'package:translation_app/widgets/fullscreen_markdown_viewer.dart';
import 'package:translation_app/widgets/translated_text_scope.dart';
import 'package:translation_app/widgets/translation_copy_actions.dart';

// ── Output area ──────────────────────────────────────────────────────

class OutputArea extends StatelessWidget {
  final TranslationState state;

  const OutputArea({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (state) {
        TranslationIdle() => const SizedBox(key: ValueKey('idle')),
        TranslationLoading() => const BiDiMarkdownView.loading(key: ValueKey('loading')),
        TranslationStreaming(:final partial) => Column(
          key: const ValueKey('streaming'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.homeOutputTitle, style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: l10n.homeCopyTooltip,
                  onPressed: () => copyTranslationText(context, partial),
                  onLongPress: () => showCopyOptions(context, partial),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 20),
                  tooltip: l10n.homeExpandOutputTooltip,
                  onPressed: () => showFullscreenMarkdownViewer(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TranslatedTextScope(
              child: BiDiMarkdownView.streaming(partial: partial, selectable: true),
            ),
          ],
        ),
        TranslationDone(:final fullText, :final modelUsed, :final durationMs) =>
          Column(
            key: const ValueKey('done'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.homeOutputTitle, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: l10n.homeCopyTooltip,
                    onPressed: () => copyTranslationText(context, fullText),
                    onLongPress: () => showCopyOptions(context, fullText),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full, size: 20),
                    tooltip: l10n.homeExpandOutputTooltip,
                    onPressed: () => showFullscreenMarkdownViewer(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeModelInfo(modelUsed, durationMs ~/ 1000),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              TranslatedTextScope(
                child: BiDiMarkdownView(markdownText: fullText, selectable: true),
              ),
            ],
          ),
        TranslationError(:final message) => Container(
          key: const ValueKey('error'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}
