import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_core/translation_core.dart';

import '../services/settings_repository.dart';

/// Provides the [FlutterSecureStorage] singleton.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(aOptions: AndroidOptions());
});

/// Provides the [SharedPreferences] singleton.
///
/// Must be overridden in `main()` before the app runs.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main()',
  );
});

/// Provides the [SettingsRepository] instance.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    secureStorage: ref.watch(secureStorageProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

// ═══════════════════════════════════════════════════════════════════════
// ── Language & Word Limit ────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Reactive state for the currently selected target language.
///
/// Use [TargetLanguageNotifier.set] to change the value and persist it.
final targetLanguageProvider = NotifierProvider<TargetLanguageNotifier, String>(
  TargetLanguageNotifier.new,
);

/// Notifier that manages the target language and persists changes.
class TargetLanguageNotifier extends Notifier<String> {
  @override
  String build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.defaultTargetLanguage;
  }

  /// Updates the target language in memory and persists it.
  Future<void> set(String value) async {
    state = value;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDefaultTargetLanguage(value);
  }
}

/// Reactive state for the current word limit.
final wordLimitProvider = NotifierProvider<WordLimitNotifier, int>(
  WordLimitNotifier.new,
);

/// Notifier that manages the word limit and persists changes.
class WordLimitNotifier extends Notifier<int> {
  @override
  int build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.wordLimit;
  }

  /// Updates the word limit in memory and persists it.
  Future<void> set(int value) async {
    state = value;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setWordLimit(value);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ── API Keys ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Provides the list of all API key entries.
final apiKeysProvider = NotifierProvider<ApiKeysNotifier, List<ApiKeyEntry>>(
  ApiKeysNotifier.new,
);

/// Notifier that manages API key entries and persists mutations.
class ApiKeysNotifier extends Notifier<List<ApiKeyEntry>> {
  @override
  List<ApiKeyEntry> build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getAllApiKeys();
  }

  /// Saves an API key entry.
  ///
  /// If the underlying repository call throws (e.g. secure storage failure),
  /// the exception is logged via [debugPrint] and re-thrown so callers can
  /// surface the error to the user.
  Future<void> saveApiKey(ApiKeyEntry entry, String keyValue) async {
    try {
      final repo = ref.read(settingsRepositoryProvider);
      await repo.saveApiKey(entry, keyValue);
      state = repo.getAllApiKeys();
    } catch (e) {
      debugPrint('Failed to save API key: $e');
      rethrow;
    }
  }

  /// Deletes an API key entry and cascades the deletion to any profiles
  /// that reference it.
  ///
  /// Profiles that used the deleted key as their primary or fallback API key
  /// will have those fields set to `null` so that translation attempts produce
  /// a clear "No API key configured" message rather than failing silently.
  Future<void> deleteApiKey(String id) async {
    final repo = ref.read(settingsRepositoryProvider);

    // Capture the entry name before deletion for the cascade warning.
    final entry = state.where((e) => e.id == id).firstOrNull;
    final entryName = entry?.name ?? id;

    await repo.deleteApiKey(id);
    state = repo.getAllApiKeys();

    // Cascade: clear dangling references in profiles.
    final profiles = ref.read(profilesProvider);
    final affectedProfileIds = <String>{};
    for (final profile in profiles) {
      bool needsUpdate = false;
      String? newApiKeyId = profile.apiKeyId;
      String? newFallbackApiKeyId = profile.fallbackApiKeyId;

      if (profile.apiKeyId == id) {
        newApiKeyId = null;
        needsUpdate = true;
      }
      if (profile.fallbackApiKeyId == id) {
        newFallbackApiKeyId = null;
        needsUpdate = true;
      }

      if (needsUpdate) {
        affectedProfileIds.add(profile.id);

        final updated = profile.copyWith(
          apiKeyId: newApiKeyId,
          fallbackApiKeyId: newFallbackApiKeyId,
        );
        await ref.read(profilesProvider.notifier).saveProfile(updated);
      }
    }

    // Cascade: check templates referencing affected profiles.
    if (affectedProfileIds.isNotEmpty) {
      final templates = ref.read(templatesProvider);
      final affectedTemplates = templates
          .where((t) => affectedProfileIds.contains(t.profileId))
          .toList();
      if (affectedTemplates.isNotEmpty) {
        debugPrint(
          'Warning: ${affectedTemplates.length} template(s) reference profiles '
          'with deleted API key "$entryName". '
          'Templates: ${affectedTemplates.map((t) => t.name).join(", ")}',
        );
      }
    }
  }

  /// Gets the actual API key value for a given ID.
  Future<String?> getApiKeyValue(String id) async {
    final repo = ref.read(settingsRepositoryProvider);
    return repo.getApiKeyValue(id);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ── Profiles ─────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Provides the list of all provider profiles.
final profilesProvider =
    NotifierProvider<ProfilesNotifier, List<ProviderProfile>>(
      ProfilesNotifier.new,
    );

/// Notifier that manages provider profiles and persists mutations.
class ProfilesNotifier extends Notifier<List<ProviderProfile>> {
  @override
  List<ProviderProfile> build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getAllProfiles();
  }

  /// Saves a provider profile.
  Future<void> saveProfile(ProviderProfile profile) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveProfile(profile);
    state = repo.getAllProfiles();
  }

  /// Deletes a provider profile.
  ///
  /// Also deletes all templates that reference this profile, and clears
  /// home selections if they pointed to the deleted profile or its templates.
  Future<void> deleteProfile(String id) async {
    final repo = ref.read(settingsRepositoryProvider);

    // Get the profile name before deletion for potential warnings.
    final profile = state.where((p) => p.id == id).firstOrNull;
    final profileName = profile?.name ?? id;

    // Get templates that reference this profile — they'll be cascade deleted.
    final templates = ref.read(templatesProvider);
    final affectedTemplateIds = templates
        .where((t) => t.profileId == id)
        .map((t) => t.id)
        .toList();

    // Delete the profile (this also removes it from SharedPreferences).
    await repo.deleteProfile(id);
    state = repo.getAllProfiles();

    // Cascade: delete all templates that reference this profile.
    if (affectedTemplateIds.isNotEmpty) {
      for (final templateId in affectedTemplateIds) {
        await repo.deleteTemplate(templateId);
      }
      // Refresh templates state.
      ref.read(templatesProvider.notifier).state = repo.getAllTemplates();

      debugPrint(
        'Cascade deletion: ${affectedTemplateIds.length} template(s) deleted '
        'because profile "$profileName" was removed.',
      );
    }

    // Cascade: clear selections if they reference deleted items.
    final selectedTextTemplate = ref.read(selectedTextTemplateProvider);
    if (affectedTemplateIds.contains(selectedTextTemplate)) {
      await ref.read(selectedTextTemplateProvider.notifier).set(null);
    }

    final selectedImageTemplate = ref.read(selectedImageTemplateProvider);
    if (affectedTemplateIds.contains(selectedImageTemplate)) {
      await ref.read(selectedImageTemplateProvider.notifier).set(null);
    }

    if (id == ref.read(selectedFallbackProfileProvider)) {
      await ref.read(selectedFallbackProfileProvider.notifier).set(null);
    }
  }

  /// Refreshes the state from the repository.
  ///
  /// Used after bulk operations like restoration to sync Riverpod state.
  void refresh() {
    final repo = ref.read(settingsRepositoryProvider);
    state = repo.getAllProfiles();
  }
}

/// Provides a specific profile by ID.
final profileByIdProvider = Provider.family<ProviderProfile?, String>((
  ref,
  id,
) {
  final profiles = ref.watch(profilesProvider);
  for (final p in profiles) {
    if (p.id == id) return p;
  }
  return null;
});

// ═══════════════════════════════════════════════════════════════════════
// ── Templates ────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Provides the list of all prompt templates.
final templatesProvider =
    NotifierProvider<TemplatesNotifier, List<PromptTemplate>>(
      TemplatesNotifier.new,
    );

/// Notifier that manages prompt templates and persists mutations.
class TemplatesNotifier extends Notifier<List<PromptTemplate>> {
  @override
  List<PromptTemplate> build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.getAllTemplates();
  }

  /// Saves a prompt template.
  Future<void> saveTemplate(PromptTemplate template) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveTemplate(template);
    state = repo.getAllTemplates();
  }

  /// Deletes a prompt template.
  Future<void> deleteTemplate(String id) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.deleteTemplate(id);
    state = repo.getAllTemplates();
  }

  /// Refreshes the state from the repository.
  ///
  /// Used after bulk operations like restoration to sync Riverpod state.
  void refresh() {
    final repo = ref.read(settingsRepositoryProvider);
    state = repo.getAllTemplates();
  }
}

/// Provides templates filtered for a specific profile.
final templatesForProfileProvider =
    Provider.family<List<PromptTemplate>, String>((ref, profileId) {
      final templates = ref.watch(templatesProvider);
      return templates.where((t) => t.profileId == profileId).toList();
    });

/// Provides templates that support text translation.
final textTemplatesProvider = Provider<List<PromptTemplate>>((ref) {
  final templates = ref.watch(templatesProvider);
  return templates.where((t) => t.supportsText).toList();
});

/// Provides templates that support image translation.
final imageTemplatesProvider = Provider<List<PromptTemplate>>((ref) {
  final templates = ref.watch(templatesProvider);
  return templates.where((t) => t.supportsImage).toList();
});

// ═══════════════════════════════════════════════════════════════════════
// ── Home Selections ──────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Provides the ID of the selected text template.
final selectedTextTemplateProvider =
    NotifierProvider<SelectedTextTemplateNotifier, String?>(
      SelectedTextTemplateNotifier.new,
    );

/// Notifier that manages the selected text template ID and persists changes.
class SelectedTextTemplateNotifier extends Notifier<String?> {
  @override
  String? build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.selectedTextTemplateId;
  }

  /// Updates the selected text template in memory and persists it.
  Future<void> set(String? id) async {
    state = id;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSelectedTextTemplateId(id);
  }
}

/// Provides the ID of the selected image template.
final selectedImageTemplateProvider =
    NotifierProvider<SelectedImageTemplateNotifier, String?>(
      SelectedImageTemplateNotifier.new,
    );

/// Notifier that manages the selected image template ID and persists changes.
class SelectedImageTemplateNotifier extends Notifier<String?> {
  @override
  String? build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.selectedImageTemplateId;
  }

  /// Updates the selected image template in memory and persists it.
  Future<void> set(String? id) async {
    state = id;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSelectedImageTemplateId(id);
  }
}

/// Provides the ID of the selected fallback profile.
final selectedFallbackProfileProvider =
    NotifierProvider<SelectedFallbackProfileNotifier, String?>(
      SelectedFallbackProfileNotifier.new,
    );

/// Notifier that manages the selected fallback profile ID and persists changes.
class SelectedFallbackProfileNotifier extends Notifier<String?> {
  @override
  String? build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.selectedFallbackProfileId;
  }

  /// Updates the selected fallback profile in memory and persists it.
  Future<void> set(String? id) async {
    state = id;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSelectedFallbackProfileId(id);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ── Overlay Settings ──────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Provides the ID of the selected overlay template.
final selectedOverlayTemplateProvider =
    NotifierProvider<SelectedOverlayTemplateNotifier, String?>(
      SelectedOverlayTemplateNotifier.new,
    );

/// Notifier that manages the selected overlay template ID and persists changes.
class SelectedOverlayTemplateNotifier extends Notifier<String?> {
  @override
  String? build() {
    final repo = ref.watch(settingsRepositoryProvider);
    final templates = ref.watch(templatesProvider);
    final savedId = repo.selectedOverlayTemplateId;

    if (savedId != null && !templates.any((t) => t.id == savedId)) {
      Future.microtask(() async {
        await repo.setSelectedOverlayTemplateId(null);
        state = null;
      });
      return null;
    }

    return savedId;
  }

  /// Updates the selected overlay template in memory and persists it.
  Future<void> set(String? id) async {
    state = id;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSelectedOverlayTemplateId(id);
  }
}

/// Provides templates suitable for overlay (both text and image support).
final overlayTemplatesProvider = Provider<List<PromptTemplate>>((ref) {
  final templates = ref.watch(templatesProvider);
  return templates.where((t) => t.supportsText || t.supportsImage).toList();
});

/// Provides the overlay size mode (compressed or full).
final overlaySizeModeProvider =
    NotifierProvider<OverlaySizeModeNotifier, OverlaySizeMode>(
      OverlaySizeModeNotifier.new,
    );

/// Notifier that manages the overlay size mode and persists changes.
class OverlaySizeModeNotifier extends Notifier<OverlaySizeMode> {
  @override
  OverlaySizeMode build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.overlaySizeMode;
  }

  /// Updates the overlay size mode in memory and persists it.
  Future<void> set(OverlaySizeMode mode) async {
    state = mode;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setOverlaySizeMode(mode);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ── Restore Built-in Items ───────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Provider that exposes a method to restore missing built-in profiles
/// and templates. Returns the count of restored items.
final restoreBuiltInProvider = Provider<RestoreBuiltInNotifier>((ref) {
  return RestoreBuiltInNotifier(ref);
});

/// Notifier that handles restoration of built-in items.
class RestoreBuiltInNotifier {
  final Ref _ref;

  RestoreBuiltInNotifier(this._ref);

  /// Restores any missing built-in profiles and templates.
  ///
  /// Returns a [RestoreResult] containing counts of what was restored.
  Future<RestoreResult> restore() async {
    final repo = _ref.read(settingsRepositoryProvider);

    // Capture counts before restoration.
    final profilesBefore = repo.getAllProfiles().length;
    final templatesBefore = repo.getAllTemplates().length;

    // Run restoration.
    await repo.restoreBuiltInItems();

    // Capture counts after restoration.
    final profilesAfter = repo.getAllProfiles().length;
    final templatesAfter = repo.getAllTemplates().length;

    // Refresh Riverpod state for profiles and templates via notifier methods.
    _ref.read(profilesProvider.notifier).refresh();
    _ref.read(templatesProvider.notifier).refresh();

    return RestoreResult(
      profilesRestored: profilesAfter - profilesBefore,
      templatesRestored: templatesAfter - templatesBefore,
    );
  }
}

/// Result of a built-in restoration operation.
class RestoreResult {
  /// Number of profiles that were created.
  final int profilesRestored;

  /// Number of templates that were created.
  final int templatesRestored;

  /// Creates a [RestoreResult].
  const RestoreResult({
    required this.profilesRestored,
    required this.templatesRestored,
  });

  /// Total number of items restored.
  int get totalRestored => profilesRestored + templatesRestored;
}

// ═══════════════════════════════════════════════════════════════════════
// ── Theme Mode ────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Reactive state for the user's selected theme mode.
///
/// Persists across launches via [SettingsRepository.setThemeMode]. Defaults
/// to [ThemeMode.system] for first-launch users.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Notifier that manages the theme mode and persists changes.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.themeMode;
  }

  /// Updates the theme mode in memory and persists it.
  Future<void> set(ThemeMode mode) async {
    state = mode;
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setThemeMode(mode);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ── App Locale ────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════

/// Supported UI language codes.
///
/// The set is intentionally small for the MVP. To add a new locale, append
/// its language code here and add a corresponding ARB file under
/// `lib/l10n/`.
abstract class AppLanguageCodes {
  /// English language code.
  static const english = 'en';

  /// Arabic language code.
  static const arabic = 'ar';
}

/// Reactive state for the user-selected app UI locale.
///
/// Returns `null` when the user has not picked a locale, which tells the
/// app to fall back to the device's system locale. Changes are persisted
/// to [SharedPreferences] under [_appLocalePrefKey] so the choice survives
/// app restarts.
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(
  AppLocaleNotifier.new,
);

/// Notifier that manages the user-selected app UI locale.
///
/// Pass `null` to [set] to clear the user choice and revert to the system
/// locale.
class AppLocaleNotifier extends Notifier<Locale?> {
  /// SharedPreferences key under which the chosen language code is stored.
  static const String _appLocalePrefKey = 'app_locale';

  @override
  Locale? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _localeFromCode(prefs.getString(_appLocalePrefKey));
  }

  /// Updates the app UI locale in memory and persists it.
  ///
  /// Passing `null` removes the user override and lets the app fall back
  /// to the device's system locale on the next rebuild.
  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(_appLocalePrefKey);
    } else {
      await prefs.setString(_appLocalePrefKey, locale.languageCode);
    }
  }

  /// Resolves a stored language code to a [Locale], or `null` when the
  /// code is missing, empty, or not one of the supported app languages.
  static Locale? _localeFromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    switch (code) {
      case AppLanguageCodes.english:
        return const Locale('en', '');
      case AppLanguageCodes.arabic:
        return const Locale('ar', '');
      default:
        return null;
    }
  }
}
