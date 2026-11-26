import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';

// ── Template selector row ────────────────────────────────────────────

/// Row with two template selectors: one for text, one for image.
///
/// Each selector shows the currently selected template name + profile name.
/// On tap, shows a bottom sheet with templates grouped by profile.
class TemplateSelectorRow extends ConsumerWidget {
  const TemplateSelectorRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectedTextId = ref.watch(selectedTextTemplateProvider);
    final selectedImageId = ref.watch(selectedImageTemplateProvider);
    final templates = ref.watch(templatesProvider);
    final profiles = ref.watch(profilesProvider);

    // Resolve selected template names.
    String textLabel = l10n.homeSelectTextTemplate;
    String? textProfileName;
    for (final t in templates) {
      if (t.id == selectedTextId) {
        textLabel = t.name;
        for (final p in profiles) {
          if (p.id == t.profileId) {
            textProfileName = p.name;
          }
        }
      }
    }

    String imageLabel = l10n.homeSelectImageTemplate;
    String? imageProfileName;
    for (final t in templates) {
      if (t.id == selectedImageId) {
        imageLabel = t.name;
        for (final p in profiles) {
          if (p.id == t.profileId) {
            imageProfileName = p.name;
          }
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: TemplateSelectorChip(
            icon: Icons.text_fields,
            label: textLabel,
            profileName: textProfileName,
            onTap: () =>
                _showTemplatePicker(context, ref, supportsImage: false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TemplateSelectorChip(
            icon: Icons.image_outlined,
            label: imageLabel,
            profileName: imageProfileName,
            onTap: () => _showTemplatePicker(context, ref, supportsImage: true),
          ),
        ),
      ],
    );
  }

  /// Shows a bottom sheet with templates filtered by capability, grouped
  /// by profile.
  Future<void> _showTemplatePicker(
    BuildContext context,
    WidgetRef ref, {
    required bool supportsImage,
  }) async {
    final templates = ref.read(templatesProvider);
    final profiles = ref.read(profilesProvider);
    final selectedId = supportsImage
        ? ref.read(selectedImageTemplateProvider)
        : ref.read(selectedTextTemplateProvider);

    // Filter templates by capability.
    final filtered = templates.where((t) {
      return supportsImage ? t.supportsImage : t.supportsText;
    }).toList();

    // Group by profile.
    final grouped = <String, List<PromptTemplate>>{};
    for (final t in filtered) {
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
              supportsImage
                  ? AppLocalizations.of(ctx).homeImageTemplateTitle
                  : AppLocalizations.of(ctx).homeTextTemplateTitle,
              style: Theme.of(ctx).textTheme.titleMedium,
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
                    trailing: template.id == selectedId
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      if (supportsImage) {
                        ref
                            .read(selectedImageTemplateProvider.notifier)
                            .set(template.id);
                      } else {
                        ref
                            .read(selectedTextTemplateProvider.notifier)
                            .set(template.id);
                      }
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

/// A single template selector chip showing icon, label, and profile name.
class TemplateSelectorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? profileName;
  final VoidCallback onTap;

  const TemplateSelectorChip({
    super.key,
    required this.icon,
    required this.label,
    required this.profileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (profileName != null)
                    Text(
                      profileName!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
