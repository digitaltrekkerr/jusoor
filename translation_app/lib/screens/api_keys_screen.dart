import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../services/settings_repository.dart';

/// Full CRUD screen for managing named API keys.
///
/// Displays a list of API key entries with obscured values. Supports
/// adding, editing, and deleting keys via dialogs.
class ApiKeysScreen extends ConsumerWidget {
  /// Creates the [ApiKeysScreen].
  const ApiKeysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKeys = ref.watch(apiKeysProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.apiKeysTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.apiKeysAddTooltip,
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: apiKeys.isEmpty
          ? Center(
              child: Text(
                l10n.apiKeysEmptyState,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: apiKeys.length + 1,
              itemBuilder: (context, index) {
                if (index == apiKeys.length) {
                  // Trailing CTA so users can add a new key without
                  // reaching for the AppBar "+" icon. Matches the
                  // discoverability guidance added with the
                  // profile-edit access dialog.
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditDialog(context, ref, null),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.apiKeysAddNewButton),
                    ),
                  );
                }
                final entry = apiKeys[index];
                return _ApiKeyCard(
                  entry: entry,
                  onEdit: () => _showEditDialog(context, ref, entry),
                  onDelete: () => _confirmDelete(context, ref, entry),
                );
              },
            ),
    );
  }

  /// Shows a dialog for creating or editing an API key.
  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    ApiKeyEntry? existing,
  ) async {
    final isEditing = existing != null;
    final nameController = TextEditingController(text: existing?.name ?? '');
    final valueController = TextEditingController();
    bool obscureValue = true;

    // If editing, load the current key value.
    if (isEditing) {
      final notifier = ref.read(apiKeysProvider.notifier);
      final currentValue = await notifier.getApiKeyValue(existing.id);
      if (!context.mounted) return;
      valueController.text = currentValue ?? '';
    }

    final formKey = GlobalKey<FormState>();
    final l10n = AppLocalizations.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isEditing ? l10n.apiKeysEditTitle : l10n.apiKeysAddTitle,
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.commonName,
                    hintText: l10n.apiKeysNameHint,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.apiKeysNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: valueController,
                  obscureText: obscureValue,
                  decoration: InputDecoration(
                    labelText: l10n.apiKeysValueLabel,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureValue ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setDialogState(() => obscureValue = !obscureValue);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.apiKeysValueRequired;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.appCancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    final name = nameController.text.trim();
    final value = valueController.text.trim();

    final notifier = ref.read(apiKeysProvider.notifier);
    final id = isEditing
        ? existing.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    try {
      await notifier.saveApiKey(ApiKeyEntry(id: id, name: name), value);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.apiKeysSaveFailed('$e')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Confirms and deletes an API key entry.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ApiKeyEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.apiKeysDeleteTitle),
        content: Text(l10n.apiKeysDeleteBody(entry.name)),
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
      await ref.read(apiKeysProvider.notifier).deleteApiKey(entry.id);
    }
  }
}

/// A single API key card showing name and obscured value.
class _ApiKeyCard extends ConsumerWidget {
  final ApiKeyEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ApiKeyCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(entry.name),
        subtitle: _ObscuredKeyValue(entryId: entry.id),
        leading: const Icon(Icons.vpn_key),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: AppLocalizations.of(context).commonEdit,
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              tooltip: AppLocalizations.of(context).commonDelete,
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

/// Displays an obscured version of an API key value.
class _ObscuredKeyValue extends ConsumerStatefulWidget {
  final String entryId;

  const _ObscuredKeyValue({required this.entryId});

  @override
  ConsumerState<_ObscuredKeyValue> createState() => _ObscuredKeyValueState();
}

class _ObscuredKeyValueState extends ConsumerState<_ObscuredKeyValue> {
  String _display = '••••••••';

  @override
  void initState() {
    super.initState();
    _loadValue();
  }

  Future<void> _loadValue() async {
    final value = await ref
        .read(apiKeysProvider.notifier)
        .getApiKeyValue(widget.entryId);
    if (!mounted) return;
    if (value == null || value.isEmpty) {
      setState(
        () => _display = AppLocalizations.of(context).apiKeysEmptyValue,
      );
      return;
    }
    if (value.length <= 7) {
      setState(() => _display = '${value.substring(0, 3)}••••');
    } else {
      setState(
        () => _display =
            '${value.substring(0, 3)}••••${value.substring(value.length - 4)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _display,
      style: theme.textTheme.bodySmall?.copyWith(
        fontFamily: 'monospace',
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
