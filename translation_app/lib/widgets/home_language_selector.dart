import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/widgets/language_dropdown.dart';

// ── Language selector ────────────────────────────────────────────────

/// Target-language dropdown for the home screen.
///
/// A single language selector; the two-column grid lives inside the
/// selection modal ([LanguageDropdown] / `SelectionModal`).
class LanguageSelectorRow extends ConsumerWidget {
  const LanguageSelectorRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final targetLang = ref.watch(targetLanguageProvider);

    return Semantics(
      label: l10n.langRow_targetTooltip,
      container: true,
      child: LanguageDropdown(
        selected: targetLang,
        onChanged: (v) => ref.read(targetLanguageProvider.notifier).set(v),
        hintText: l10n.homeTargetLanguageHint,
      ),
    );
  }
}
