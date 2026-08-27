import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import 'template_edit_screen.dart';

/// List of templates grouped by profile using expansion tiles.
///
/// Shows built-in templates with a badge, non-built-in templates can be deleted.
class TemplatesScreen extends ConsumerWidget {
  /// Creates the [TemplatesScreen].
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templatesProvider);
    final profiles = ref.watch(profilesProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTemplates),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.templatesAddTooltip,
            onPressed: () => _navigateToEdit(context, null),
          ),
        ],
      ),
      body: templates.isEmpty
          ? Center(
              child: Text(
                l10n.templatesEmptyState,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _buildGroupedTemplates(
                context,
                ref,
                profiles,
                templates,
              ),
            ),
    );
  }

  /// Builds a list of [ExpansionTile] widgets, one per profile that has
  /// templates.
  List<Widget> _buildGroupedTemplates(
    BuildContext context,
    WidgetRef ref,
    List<ProviderProfile> profiles,
    List<PromptTemplate> templates,
  ) {
    // Group templates by profile ID.
    final grouped = <String, List<PromptTemplate>>{};
    for (final template in templates) {
      grouped.putIfAbsent(template.profileId, () => []).add(template);
    }

    // Include profiles that have templates.
    final tiles = <Widget>[];
    for (final profile in profiles) {
      final profileTemplates = grouped[profile.id];
      if (profileTemplates == null || profileTemplates.isEmpty) continue;

      tiles.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Row(
              children: [
                Expanded(child: Text(profile.name)),
                const SizedBox(width: 8),
                _ProviderTypeBadge(type: profile.providerType),
              ],
            ),
            children: [
              for (final template in profileTemplates)
                _TemplateTile(
                  template: template,
                  profile: profile,
                  onTap: () => _navigateToEdit(context, template),
                  onDelete: () => _confirmDelete(context, ref, template),
                ),
            ],
          ),
        ),
      );
    }

    // Also include templates whose profile no longer exists.
    final orphanTemplates = templates
        .where((t) => !profiles.any((p) => p.id == t.profileId))
        .toList();
    if (orphanTemplates.isNotEmpty) {
      tiles.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Row(
              children: [
                Text(AppLocalizations.of(context).templatesUnknownProfile),
                const SizedBox(width: 8),
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
              ],
            ),
            children: [
              for (final template in orphanTemplates)
                _TemplateTile(
                  template: template,
                  profile: null,
                  onTap: () => _navigateToEdit(context, template),
                  onDelete: () => _confirmDelete(context, ref, template),
                ),
            ],
          ),
        ),
      );
    }

    return tiles;
  }

  /// Navigates to the template edit screen.
  Future<void> _navigateToEdit(
    BuildContext context,
    PromptTemplate? template,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TemplateEditScreen(template: template)),
    );
  }

  /// Confirms and deletes a prompt template.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    PromptTemplate template,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.templatesDeleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.templatesDeleteBody(template.name)),
            if (template.isBuiltIn) ...[
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
                        l10n.templatesBuiltInWarning,
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
      await ref.read(templatesProvider.notifier).deleteTemplate(template.id);
    }
  }
}

/// A single template list tile showing name and capability badges.
class _TemplateTile extends StatelessWidget {
  final PromptTemplate template;
  final ProviderProfile? profile;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _TemplateTile({
    required this.template,
    required this.profile,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(template.name)),
          const SizedBox(width: 8),
          if (template.supportsText)
            _CapabilityBadge(label: l10n.badgeText, color: Colors.blue, theme: theme),
          if (template.supportsImage) ...[
            const SizedBox(width: 4),
            _CapabilityBadge(
              label: l10n.badgeImage,
              color: Colors.purple,
              theme: theme,
            ),
          ],
          if (template.isBuiltIn) ...[
            const SizedBox(width: 4),
            _BuiltInBadge(),
          ],
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          Icons.delete_outline,
          size: 20,
          color: theme.colorScheme.error,
        ),
        tooltip: l10n.commonDelete,
        onPressed: onDelete,
      ),
      onTap: onTap,
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
    final color = _colorForType(type);
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

  Color _colorForType(ProviderType type) {
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

/// A small badge for template capabilities (Text/Image).
class _CapabilityBadge extends StatelessWidget {
  final String label;
  final Color color;
  final ThemeData theme;

  const _CapabilityBadge({
    required this.label,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontSize: 10),
      ),
    );
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
