import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/update_provider.dart';
import '../services/settings_repository.dart';
import '../widgets/language_dropdown.dart';
import '../widgets/selection_modal.dart';
import 'api_keys_screen.dart';
import 'articles_screen.dart';
import 'instructions_screen.dart';
import 'permissions_screen.dart';
import 'profiles_screen.dart';
import 'support_screen.dart';
import 'templates_screen.dart';
import 'tips_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = true;

  final _wordLimitController = TextEditingController();
  final _wordLimitFocus = FocusNode();

  Timer? _wordLimitDebounce;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _installFocusListeners();
  }

  @override
  void dispose() {
    _wordLimitDebounce?.cancel();

    _wordLimitController.dispose();

    _wordLimitFocus.dispose();

    super.dispose();
  }

  Future<void> _loadSettings() async {
    final repo = ref.read(settingsRepositoryProvider);

    _wordLimitController.text = repo.wordLimit.toString();

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _installFocusListeners() {
    _wordLimitFocus.addListener(() {
      if (!_wordLimitFocus.hasFocus) _saveWordLimit();
    });
  }

  Future<void> _saveWordLimit() async {
    final parsed = int.tryParse(_wordLimitController.text.trim());
    if (parsed == null || parsed < 1) return;
    await ref.read(wordLimitProvider.notifier).set(parsed);
  }

  void _onWordLimitChanged(String _) {
    _wordLimitDebounce?.cancel();
    _wordLimitDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveWordLimit();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profiles = ref.watch(profilesProvider);
    final fallbackProfileId = ref.watch(selectedFallbackProfileProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        children: [
          const _UpdateAvailableBanner(),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(l10n.settingsApiKeys),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ApiKeysScreen())),
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(l10n.settingsProviderProfiles),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfilesScreen())),
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.settingsTemplates),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TemplatesScreen())),
          ),
          const SizedBox(height: 24),

          _SectionHeader(
            title: l10n.settingsSectionOverlay,
            icon: Icons.layers_outlined,
          ),
          const SizedBox(height: 8),

          _OverlayTemplateSelector(templates: ref.watch(overlayTemplatesProvider)),
          const SizedBox(height: 12),
          _OverlaySizeModeSelector(),
          const SizedBox(height: 24),

          _SectionHeader(title: l10n.settingsSectionGeneral, icon: Icons.tune),
          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.translate),
            title: Text(l10n.settingsDefaultTargetLanguage),
            subtitle: _TargetLanguageSelector(),
          ),
          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsAppLanguage),
            subtitle: _AppLanguageValue(),
            onTap: () => _showAppLanguagePicker(context, ref),
          ),
          const SizedBox(height: 8),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsThemeMode),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: _ThemeModeSelector(),
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _wordLimitController,
            focusNode: _wordLimitFocus,
            keyboardType: TextInputType.number,
            onChanged: _onWordLimitChanged,
            decoration: InputDecoration(
              labelText: l10n.settingsWordLimit,
              hintText: l10n.settingsWordLimitHint,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 24),

          _SectionHeader(
            title: l10n.settingsSectionAdvanced,
            icon: Icons.settings_suggest_outlined,
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String?>(
            key: ValueKey(fallbackProfileId),
            initialValue: profiles.any((p) => p.id == fallbackProfileId)
                ? fallbackProfileId
                : null,
            decoration: InputDecoration(
              labelText: l10n.settingsFallbackProfile,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.backup_outlined),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.settingsNoneOption),
              ),
              for (final profile in profiles)
                DropdownMenuItem<String?>(
                  value: profile.id,
                  child: Text(profile.name),
                ),
            ],
            onChanged: (v) {
              ref.read(selectedFallbackProfileProvider.notifier).set(v);
            },
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            onPressed: () => _restoreBuiltInItems(context, ref),
            icon: const Icon(Icons.restore_outlined),
            label: Text(l10n.settingsRestoreBuiltIn),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),

          _SectionHeader(
            title: l10n.settingsSectionHelp,
            icon: Icons.help_outline,
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite_outline),
            title: Text(l10n.settingsSupport),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.settingsPermissions),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PermissionsScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(l10n.settingsInstructions),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(
              MaterialPageRoute(builder: (_) => const InstructionsScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(l10n.settingsTips),
            subtitle: Text(l10n.settingsTipsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TipsScreen()),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.article_outlined),
            title: Text(l10n.settingsArticles),
            subtitle: Text(l10n.settingsArticlesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArticlesScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBuiltInItems(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(restoreBuiltInProvider).restore();

    // ignore: use_build_context_synchronously
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (result.totalRestored == 0) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.settingsAlreadyPresent),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.settingsRestoredSnackbar(
              result.profilesRestored,
              result.templatesRestored,
            ),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _TargetLanguageSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetLang = ref.watch(targetLanguageProvider);
    final l10n = AppLocalizations.of(context);
    return LanguageDropdown(
      selected: targetLang,
      onChanged: (v) {
        ref.read(targetLanguageProvider.notifier).set(v);
      },
      hintText: l10n.settingsTargetLanguageHint,
    );
  }
}

/// Display-only current app-UI language value. The row itself is tappable
/// (see [_showAppLanguagePicker]); this widget just renders the value.
class _AppLanguageValue extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(appLocaleProvider);

    final label = switch (locale?.languageCode) {
      AppLanguageCodes.english => 'English',
      AppLanguageCodes.arabic => 'العربية',
      _ => l10n.settingsAppLanguageSystem,
    };

    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }
}

/// Opens the app-language picker and applies the selection. `system` maps to
/// `null` (follow the device locale); the language codes map to [Locale]s.
Future<void> _showAppLanguagePicker(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final result = await showSelectionModal<String>(
    context: context,
    title: l10n.settingsAppLanguageTitle,
    options: [
      SelectionOption(value: 'system', label: l10n.settingsAppLanguageSystem),
      const SelectionOption(value: 'en', label: 'English'),
      const SelectionOption(value: 'ar', label: 'العربية'),
    ],
    selectedValue: ref.read(appLocaleProvider)?.languageCode ?? 'system',
    columns: 2,
  );
  if (result == null) return;
  final next = switch (result) {
    AppLanguageCodes.english => const Locale('en', ''),
    AppLanguageCodes.arabic => const Locale('ar', ''),
    _ => null,
  };
  await ref.read(appLocaleProvider.notifier).set(next);
}

class _OverlayTemplateSelector extends ConsumerWidget {
  final List<PromptTemplate> templates;

  const _OverlayTemplateSelector({required this.templates});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedOverlayTemplateProvider);
    final profiles = ref.watch(profilesProvider);
    final l10n = AppLocalizations.of(context);

    String label = l10n.settingsSelectOverlayTemplate;
    String? profileName;
    for (final t in templates) {
      if (t.id == selectedId) {
        label = t.name;
        for (final p in profiles) {
          if (p.id == t.profileId) {
            profileName = p.name;
          }
        }
      }
    }

    return InkWell(
      onTap: () => _showTemplatePicker(context, ref),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.settingsOverlayTemplate,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.layers_outlined),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profileName != null)
                    Text(
                      profileName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _showTemplatePicker(BuildContext context, WidgetRef ref) async {
    final selectedId = ref.read(selectedOverlayTemplateProvider);
    final profiles = ref.read(profilesProvider);
    final l10n = AppLocalizations.of(context);

    final grouped = <String, List<PromptTemplate>>{};
    for (final t in templates) {
      grouped.putIfAbsent(t.profileId, () => []).add(t);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.settingsOverlayTemplate,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsOverlayTemplateDescription,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final profile in profiles)
              if (grouped.containsKey(profile.id)) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, top: 8),
                  child: Text(
                    profile.name,
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                ),
                for (final template in grouped[profile.id]!)
                  ListTile(
                    title: Text(template.name),
                    subtitle: Text(
                      template.supportsText && template.supportsImage
                          ? l10n.settingsOverlayTextAndImage
                          : template.supportsText
                              ? l10n.settingsOverlayTextOnly
                              : l10n.settingsOverlayImageOnly,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    trailing: template.id == selectedId
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      ref
                          .read(selectedOverlayTemplateProvider.notifier)
                          .set(template.id);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

class _OverlaySizeModeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(overlaySizeModeProvider);
    final l10n = AppLocalizations.of(context);
    final label = mode == OverlaySizeMode.compressed
        ? l10n.settingsOverlaySizeCompressed
        : l10n.settingsOverlaySizeFull;

    return InkWell(
      onTap: () => _showModePicker(context, ref),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.settingsSizeMode,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.aspect_ratio),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _showModePicker(BuildContext context, WidgetRef ref) async {
    final current = ref.read(overlaySizeModeProvider);
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.6,
        expand: false,
        builder: (ctx, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.settingsOverlaySizeModeTitle,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsOverlaySizeModeDescription,
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.settingsOverlaySizeCompressed),
              subtitle: Text(
                l10n.settingsOverlaySizeCompressedDescription,
              ),
              trailing: current == OverlaySizeMode.compressed
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                ref.read(overlaySizeModeProvider.notifier).set(
                  OverlaySizeMode.compressed,
                );
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              title: Text(l10n.settingsOverlaySizeFull),
              subtitle: Text(
                l10n.settingsOverlaySizeFullDescription,
              ),
              trailing: current == OverlaySizeMode.full
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                ref.read(overlaySizeModeProvider.notifier).set(
                  OverlaySizeMode.full,
                );
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final l10n = AppLocalizations.of(context);

    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          label: Text(l10n.themeSystem),
          icon: const Icon(Icons.brightness_auto_outlined),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          label: Text(l10n.themeLight),
          icon: const Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          label: Text(l10n.themeDark),
          icon: const Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) {
        ref.read(themeModeProvider.notifier).set(selection.first);
      },
      showSelectedIcon: false,
    );
  }
}

/// Banner shown at the top of the Settings screen when a newer
/// Jusoor release exists on GitHub.
///
/// Reads [updateInfoProvider]; renders nothing while the future is
/// loading or when the check returned `hasUpdate: false` / failed
/// (the service swallows every error, so there is no error branch
/// to handle here). When an update is available, the banner offers
/// a single "Download" action that opens the release's GitHub page
/// in the user's browser via [launchUrl] — matching the existing
/// external-link pattern in `support_screen.dart`.
class _UpdateAvailableBanner extends ConsumerWidget {
  const _UpdateAvailableBanner();

  Future<void> _openReleaseUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (uri == null) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.supportInvalidUrl)),
      );
      return;
    }
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.pagesOpeningLink),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[SettingsScreen] launchUrl failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUpdate = ref.watch(updateInfoProvider);
    final info = asyncUpdate.value;
    if (info == null || !info.hasUpdate || info.releaseUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(Icons.system_update_alt, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.updateAvailableTitle,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.updateAvailableSubtitle(info.latestVersion),
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => _openReleaseUrl(context, info.releaseUrl),
                child: Text(l10n.updateAvailableAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

