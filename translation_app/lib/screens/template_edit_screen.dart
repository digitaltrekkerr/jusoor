import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../services/settings_repository.dart';

/// Default system prompt used by the application.
const _kDefaultSystemPrompt =
    'You are a professional translator. Translate the given text to '
    '{{target_language}}. Preserve the original formatting and structure.';

/// Screen for creating or editing a single prompt template.
///
/// When [template] is `null`, a new template is created. When provided,
/// the form is pre-filled with the existing template's values.
class TemplateEditScreen extends ConsumerStatefulWidget {
  /// The existing template to edit, or `null` to create a new one.
  final PromptTemplate? template;

  /// Creates the [TemplateEditScreen].
  const TemplateEditScreen({super.key, this.template});

  @override
  ConsumerState<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends ConsumerState<TemplateEditScreen> {
  // ── Controllers ─────────────────────────────────────────────────────

  final _nameController = TextEditingController();
  final _systemPromptController = TextEditingController();

  // ── Local state ─────────────────────────────────────────────────────

  String? _selectedProfileId;
  bool _supportsText = true;
  bool _supportsImage = false;
  bool _substituteTargetLanguage = true;
  bool _outputLanguageFixed = false;

  /// Whether this is an edit of an existing template.
  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  // ── Initial load ────────────────────────────────────────────────────

  void _loadTemplate() {
    final template = widget.template;
    if (template == null) return;

    _nameController.text = template.name;
    _systemPromptController.text = template.systemPrompt;
    _selectedProfileId = template.profileId;

    // Validate that the referenced profile still exists.
    final profiles = ref.read(profilesProvider);
    final validProfileIds = profiles.map((p) => p.id).toSet();
    if (!validProfileIds.contains(_selectedProfileId)) {
      debugPrint(
        'Template "${template.name}" references non-existent profile $_selectedProfileId',
      );
      _selectedProfileId = null;
    }

    _supportsText = template.supportsText;
    _supportsImage = template.supportsImage;
    _substituteTargetLanguage = template.substituteTargetLanguage;
    _outputLanguageFixed = template.outputLanguageFixed;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.tplEditExistingTitle : l10n.tplEditNewTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Name ──────────────────────────────────────────────────
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.tplEditNameLabel,
              hintText: l10n.tplEditNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Profile dropdown ──────────────────────────────────────
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedProfileId),
            initialValue: _selectedProfileId,
            decoration: InputDecoration(
              labelText: l10n.tplEditProfileLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final profile in profiles)
                DropdownMenuItem<String>(
                  value: profile.id,
                  child: Text(
                    '${profile.name} (${profile.providerType.displayName})',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selectedProfileId = v),
          ),
          const SizedBox(height: 16),

          // ── System Prompt ─────────────────────────────────────────
          if (_systemPromptMissingTargetLanguage)
            _WarningBanner(
              message: l10n.tplEditWarningMissingTarget('{{target_language}}'),
            ),
          if (_systemPromptMissingTargetLanguage) const SizedBox(height: 8),
          TextField(
            controller: _systemPromptController,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.tplEditSystemPromptLabel,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: _resetSystemPrompt,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.tplEditResetToDefault),
            ),
          ),
          const SizedBox(height: 16),

          // ── Supports Text ─────────────────────────────────────────
          SwitchListTile(
            value: _supportsText,
            title: Text(l10n.tplEditSupportsText),
            subtitle: Text(l10n.tplEditSupportsTextSubtitle),
            onChanged: (v) => setState(() => _supportsText = v),
          ),

          // ── Supports Image ────────────────────────────────────────
          SwitchListTile(
            value: _supportsImage,
            title: Text(l10n.tplEditSupportsImage),
            subtitle: Text(l10n.tplEditSupportsImageSubtitle),
            onChanged: (v) => setState(() => _supportsImage = v),
          ),

          // ── Substitute Target Language ────────────────────────────
          SwitchListTile(
            value: _substituteTargetLanguage,
            title: Text(l10n.tplSubTitle),
            subtitle: Text(l10n.tplSubSubtitle('{{target_language}}')),
            onChanged: (v) => setState(() => _substituteTargetLanguage = v),
          ),

          // ── Fixed Output Language (no {{target_language}} variable) ──
          SwitchListTile(
            value: _outputLanguageFixed,
            title: Text(l10n.tplOutLangFixedTitle),
            subtitle: Text(l10n.tplOutLangFixedSubtitle),
            onChanged: (v) => setState(() => _outputLanguageFixed = v),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveTemplate,
        icon: const Icon(Icons.save),
        label: Text(l10n.tplEditSaveButton),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  bool get _systemPromptMissingTargetLanguage {
    // Fixed-output-language templates bake the target into the prompt body
    // themselves and have no `{{target_language}}` placeholder by design —
    // do not warn about a missing placeholder that is not expected there.
    if (_outputLanguageFixed) return false;
    return !_systemPromptController.text.contains('{{target_language}}');
  }

  void _resetSystemPrompt() {
    // For built-in templates, restore the template's OWN original prompt
    // from the shipped catalog (what the user saw at first install), not a
    // generic placeholder. Custom templates fall back to the generic one.
    final template = widget.template;
    final original = template == null
        ? null
        : SettingsRepository.builtInSystemPromptFor(template.id);
    _systemPromptController.text = original ?? _kDefaultSystemPrompt;
    setState(() {});
  }

  Future<void> _saveTemplate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tplEditErrorNameRequired)),
      );
      return;
    }

    if (_selectedProfileId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tplEditErrorProfileRequired)),
      );
      return;
    }

    final systemPrompt = _systemPromptController.text.trim();
    if (systemPrompt.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tplEditErrorPromptRequired)),
      );
      return;
    }

    if (!_supportsText && !_supportsImage) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.tplEditErrorCapabilityRequired)),
      );
      return;
    }

    final id = _isEditing
        ? widget.template!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final template = PromptTemplate(
      id: id,
      profileId: _selectedProfileId!,
      name: name,
      systemPrompt: systemPrompt,
      supportsText: _supportsText,
      supportsImage: _supportsImage,
      substituteTargetLanguage: _substituteTargetLanguage,
      outputLanguageFixed: _outputLanguageFixed,
      isBuiltIn: _isEditing ? widget.template!.isBuiltIn : false,
    );

    await ref.read(templatesProvider.notifier).saveTemplate(template);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

/// Warning banner shown when a condition is not met.
class _WarningBanner extends StatelessWidget {
  final String message;

  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.error),
      ),
      leading: Icon(
        Icons.warning_amber_rounded,
        color: theme.colorScheme.error,
      ),
      title: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
