import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/widgets/bidi_markdown_view.dart';
import 'package:translation_app/widgets/translated_text_scope.dart';
import 'package:translation_app/widgets/translation_copy_actions.dart';

/// Read-only, selectable, full-screen view of the current translation.
/// Watches [translationProvider] so a streaming translation keeps growing.
class FullscreenMarkdownViewer extends ConsumerWidget {
  const FullscreenMarkdownViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(translationProvider);

    String? text;
    if (state is TranslationStreaming) {
      text = state.partial;
    } else if (state is TranslationDone) {
      text = state.fullText;
    }

    // The route is a fullscreenDialog, so Flutter already draws a leading
    // close button on the side that matches the text direction (right in
    // RTL, left in LTR). No second close action belongs in `actions`.
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeOutputFullscreenTitle),
        actions: [
          if (text != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: l10n.homeCopyTooltip,
              onPressed: () => copyTranslationText(context, text!),
              onLongPress: () => showCopyOptions(context, text!),
            ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(context, state, text),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TranslationState state, String? text) {
    final theme = Theme.of(context);

    if (state is TranslationLoading) {
      return const BiDiMarkdownView.loading();
    }
    if (state is TranslationStreaming) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TranslatedTextScope(
          child: BiDiMarkdownView.streaming(partial: state.partial, selectable: true),
        ),
      );
    }
    if (state is TranslationDone) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TranslatedTextScope(
          child: BiDiMarkdownView(markdownText: state.fullText, selectable: true),
        ),
      );
    }
    if (state is TranslationError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
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
                  state.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Pushes the viewer as a full-screen route.
Future<void> showFullscreenMarkdownViewer(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => const FullscreenMarkdownViewer(),
    ),
  );
}
