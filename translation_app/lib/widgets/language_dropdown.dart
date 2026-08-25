import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'selection_modal.dart';

/// Language entry with display name and ISO 639-1 code.
class LanguageEntry {
  final String name;
  final String code;
  const LanguageEntry({required this.name, required this.code});
}

/// Languages available for the translation target selector.
const kLanguageEntries = [
  LanguageEntry(name: 'English', code: 'en'),
  LanguageEntry(name: 'Spanish', code: 'es'),
  LanguageEntry(name: 'French', code: 'fr'),
  LanguageEntry(name: 'German', code: 'de'),
  LanguageEntry(name: 'Italian', code: 'it'),
  LanguageEntry(name: 'Portuguese', code: 'pt'),
  LanguageEntry(name: 'Russian', code: 'ru'),
  LanguageEntry(name: 'Chinese', code: 'zh'),
  LanguageEntry(name: 'Japanese', code: 'ja'),
  LanguageEntry(name: 'Korean', code: 'ko'),
  LanguageEntry(name: 'Arabic', code: 'ar'),
  LanguageEntry(name: 'Hindi', code: 'hi'),
  LanguageEntry(name: 'Turkish', code: 'tr'),
  LanguageEntry(name: 'Dutch', code: 'nl'),
  LanguageEntry(name: 'Polish', code: 'pl'),
  LanguageEntry(name: 'Swedish', code: 'sv'),
  LanguageEntry(name: 'Danish', code: 'da'),
  LanguageEntry(name: 'Finnish', code: 'fi'),
  LanguageEntry(name: 'Norwegian', code: 'no'),
  LanguageEntry(name: 'Czech', code: 'cs'),
  LanguageEntry(name: 'Greek', code: 'el'),
  LanguageEntry(name: 'Hebrew', code: 'he'),
  LanguageEntry(name: 'Thai', code: 'th'),
  LanguageEntry(name: 'Vietnamese', code: 'vi'),
  LanguageEntry(name: 'Indonesian', code: 'id'),
  LanguageEntry(name: 'Ukrainian', code: 'uk'),
  LanguageEntry(name: 'Romanian', code: 'ro'),
  LanguageEntry(name: 'Hungarian', code: 'hu'),
  LanguageEntry(name: 'Catalan', code: 'ca'),
];

/// Language list derived from kLanguageEntries.
final kLanguages = List<String>.unmodifiable(kLanguageEntries.map((e) => e.name).toList());

final kLanguageNameToCode = {for (final e in kLanguageEntries) e.name: e.code};
final kLanguageCodeToName = {for (final e in kLanguageEntries) e.code: e.name};

/// Returns the ISO code for a language name, or null if not found.
String? getLanguageCode(String languageName) {
  return kLanguageNameToCode[languageName];
}

/// Returns the language name for an ISO code, or null if not found.
String? getLanguageName(String code) {
  return kLanguageCodeToName[code];
}

/// A dropdown selector for choosing a language.
///
/// Opens a bottom-sheet selection modal ([showSelectionModal]) presenting
/// the available languages in a two-column grid.
class LanguageDropdown extends StatelessWidget {
  /// Currently selected language.
  final String selected;

  /// Callback fired when the user picks a language.
  final ValueChanged<String> onChanged;

  /// Optional hint text displayed when nothing is selected.
  final String? hintText;

  /// Creates a [LanguageDropdown].
  const LanguageDropdown({
    super.key,
    required this.selected,
    required this.onChanged,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final languages = kLanguages;

    final validSelected = languages.contains(selected)
        ? selected
        : languages.first;

    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        hintText: hintText,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final result = await showSelectionModal<String>(
            context: context,
            title: l10n.langAuto_selectTitle,
            options: languages
                .map((lang) => SelectionOption<String>(
                      value: lang,
                      label: lang,
                    ))
                .toList(),
            selectedValue: validSelected,
            searchHint: l10n.langAuto_searchHint,
            columns: 2,
          );
          if (result != null) {
            onChanged(result);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                validSelected,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}