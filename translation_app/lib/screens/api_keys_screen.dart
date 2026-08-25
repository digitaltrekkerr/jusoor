import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Keys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add API Key',
            onPressed: () => _showEditDialog(context, ref, null),
          ),
        ],
      ),
      body: apiKeys.isEmpty
          ? Center(
              child: Text(
                'No API keys yet. Tap + to add one.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: apiKeys.length,
              itemBuilder: (context, index) {
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

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit API Key' : 'Add API Key'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. OpenRouter, Gemini',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: valueController,
                  obscureText: obscureValue,
                  decoration: InputDecoration(
                    labelText: 'API Key Value',
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
                      return 'API key value is required';
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Save'),
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
            content: Text('Failed to save API key: $e'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete API Key?'),
        content: Text(
          'Are you sure you want to delete "${entry.name}"? '
          'This cannot be undone.\n\n'
          'Profiles using this key will have their API key reference removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
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
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.error,
              ),
              tooltip: 'Delete',
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
      setState(() => _display = '(empty)');
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
