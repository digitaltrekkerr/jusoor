import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../services/settings_repository.dart';
import 'profile_edit_screen.dart';

/// List of provider profiles with navigation to create/edit.
///
/// Shows built-in profiles with a badge, non-built-in profiles can be deleted.
class ProfilesScreen extends ConsumerWidget {
  /// Creates the [ProfilesScreen].
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final apiKeys = ref.watch(apiKeysProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsProviderProfiles),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.profilesAddTooltip,
            onPressed: () => _navigateToEdit(context, null),
          ),
        ],
      ),
      body: profiles.isEmpty
          ? Center(
              child: Text(
                l10n.profilesEmptyState,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final profile = profiles[index];
                final apiKeyName = _getApiKeyName(apiKeys, profile.apiKeyId);
                return _ProfileCard(
                  profile: profile,
                  apiKeyName: apiKeyName,
                  onTap: () => _navigateToEdit(context, profile),
                  onDelete: () => _confirmDelete(context, ref, profile),
                );
              },
            ),
    );
  }

  /// Resolves the display name for an API key ID.
  String? _getApiKeyName(List<ApiKeyEntry> apiKeys, String? apiKeyId) {
    if (apiKeyId == null) return null;
    for (final key in apiKeys) {
      if (key.id == apiKeyId) return key.name;
    }
    return null;
  }

  /// Navigates to the profile edit screen.
  Future<void> _navigateToEdit(
    BuildContext context,
    ProviderProfile? profile,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileEditScreen(profile: profile)),
    );
  }

  /// Confirms and deletes a provider profile.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProviderProfile profile,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profilesDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profilesDeleteBody(profile.name)),
            if (profile.isBuiltIn) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(ctx).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.profilesBuiltInWarning,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.appCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(profilesProvider.notifier).deleteProfile(profile.id);
    }
  }
}

/// A single profile card showing name, type, API key, and model.
class _ProfileCard extends StatelessWidget {
  final ProviderProfile profile;
  final String? apiKeyName;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ProfileCard({
    required this.profile,
    required this.apiKeyName,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(profile.name, style: theme.textTheme.titleMedium),
                        const SizedBox(width: 8),
                        _ProviderTypeBadge(type: profile.providerType),
                        if (profile.isBuiltIn) ...[
                          const SizedBox(width: 8),
                          _BuiltInBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.profilesModelLabel(profile.model),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (apiKeyName case final String resolvedKeyName) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.profilesApiKeyLabel(resolvedKeyName),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                tooltip: l10n.commonDelete,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small chip-like badge showing the provider type.
class _ProviderTypeBadge extends StatelessWidget {
  final ProviderType type;

  const _ProviderTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorForType(type, theme);
    final icon = _iconForType(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            type.displayName,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Color _colorForType(ProviderType type, ThemeData theme) {
    switch (type) {
      case ProviderType.openrouter:
        return Colors.orange;
      case ProviderType.gemini:
        return Colors.blue;
      case ProviderType.openaiCompatible:
        return Colors.green;
    }
  }

  IconData _iconForType(ProviderType type) {
    switch (type) {
      case ProviderType.openrouter:
        return Icons.route;
      case ProviderType.gemini:
        return Icons.auto_awesome;
      case ProviderType.openaiCompatible:
        return Icons.settings_ethernet;
    }
  }
}

/// A small "Built-in" badge for pre-built profiles and templates.
class _BuiltInBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppLocalizations.of(context).badgeBuiltIn,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontSize: 10,
        ),
      ),
    );
  }
}
