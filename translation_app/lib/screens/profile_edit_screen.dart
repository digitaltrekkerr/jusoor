import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../screens/api_keys_screen.dart';
import '../widgets/selection_modal.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final ProviderProfile? profile;

  const ProfileEditScreen({super.key, this.profile});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

/// Verdict of [validateProviderBaseUrl].
sealed class BaseUrlVerdict {
  const BaseUrlVerdict();
}

/// URL is acceptable (https, or http to a loopback host).
class BaseUrlOk extends BaseUrlVerdict {
  const BaseUrlOk();
}

/// URL could not be parsed or has no scheme.
class BaseUrlMalformed extends BaseUrlVerdict {
  const BaseUrlMalformed();
}

/// URL has a scheme other than http/https.
class BaseUrlBadScheme extends BaseUrlVerdict {
  const BaseUrlBadScheme();
}

/// URL is http to a non-loopback (remote) host — rejected.
class BaseUrlInsecureRemote extends BaseUrlVerdict {
  const BaseUrlInsecureRemote();
}

/// Validates a custom endpoint URL string.
///
/// Enforces HTTPS for remote endpoints; the only cleartext exceptions are
/// loopback addresses (`localhost`, `127.0.0.1`, `[::1]`) used by local
/// model servers such as Ollama.
BaseUrlVerdict validateProviderBaseUrl(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return const BaseUrlMalformed();
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return const BaseUrlBadScheme();
  }
  if (scheme == 'https') {
    return const BaseUrlOk();
  }
  // Allow http:// only for loopback hosts.
  final host = uri.host.toLowerCase();
  if (host == 'localhost' ||
      host == '127.0.0.1' ||
      host == '[::1]' ||
      host == '::1') {
    return const BaseUrlOk();
  }
  return const BaseUrlInsecureRemote();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();

  ProviderType _providerType = ProviderType.openrouter;
  String? _selectedApiKeyId;
  String? _selectedFallbackApiKeyId;

  List<String> _availableModels = [];
  List<String> _availableVisionModels = [];
  bool _isLoadingModels = false;
  String? _selectedModel;
  String? _selectedVisionModel;

  /// When true, the API Key `InputDecorator` renders with a red border to
  /// draw the user's attention to it. Set when the user attempts to pick
  /// a model without selecting an API key first; cleared automatically
  /// after a short animation (see [_apiKeyHighlightTimer]).
  bool _apiKeyHighlight = false;
  Timer? _apiKeyHighlightTimer;

  bool get _isEditing => widget.profile != null;

  bool get _canFetchModels => _selectedApiKeyId != null;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyHighlightTimer?.cancel();
    super.dispose();
  }

  /// Triggers a brief red-border highlight on the API Key field so the user
  /// notices where the dependency lives.
  void _flashApiKeyHighlight() {
    _apiKeyHighlightTimer?.cancel();
    setState(() => _apiKeyHighlight = true);
    _apiKeyHighlightTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _apiKeyHighlight = false);
      }
    });
  }

  /// Bottom-sheet picker shown when the user taps the Model / Vision Model
  /// field while no API key is selected. Offers a fast path to either
  /// pick an existing key or add a new one.
  Future<void> _showModelAccessDialog() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        final colorScheme = Theme.of(sheetCtx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(Icons.key_off, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.profileModelAccessTitle,
                        style: Theme.of(sheetCtx).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  l10n.profileModelAccessBody,
                  style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.key),
                title: Text(l10n.profileModelAccessPickExisting),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _flashApiKeyHighlight();
                  _selectApiKey();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(l10n.profileModelAccessAddNew),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ApiKeysScreen(),
                      fullscreenDialog: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _loadProfile() {
    final profile = widget.profile;
    if (profile == null) return;

    _nameController.text = profile.name;
    _providerType = profile.providerType;
    _selectedModel = profile.model;
    _selectedVisionModel = profile.visionModel;
    _baseUrlController.text = profile.baseUrl ?? '';

    final apiKeys = ref.read(apiKeysProvider);
    final validKeyIds = apiKeys.map((k) => k.id).toSet();
    _selectedApiKeyId = validKeyIds.contains(profile.apiKeyId)
        ? profile.apiKeyId
        : null;
    _selectedFallbackApiKeyId = validKeyIds.contains(profile.fallbackApiKeyId)
        ? profile.fallbackApiKeyId
        : null;

    if (profile.apiKeyId != _selectedApiKeyId ||
        profile.fallbackApiKeyId != _selectedFallbackApiKeyId) {
      final correctedProfile = ProviderProfile(
        id: profile.id,
        name: profile.name,
        providerType: profile.providerType,
        apiKeyId: _selectedApiKeyId,
        fallbackApiKeyId: _selectedFallbackApiKeyId,
        model: profile.model,
        visionModel: profile.visionModel,
        baseUrl: profile.baseUrl,
        isBuiltIn: profile.isBuiltIn,
      );
      ref.read(profilesProvider.notifier).saveProfile(correctedProfile);
      debugPrint(
        'Auto-fixed orphaned API key references in profile "${profile.name}"',
      );
    }

    _selectedModel = profile.model;
    _selectedVisionModel = profile.visionModel;

    if (_canFetchModels) {
      _fetchModels();
    }
  }

  Future<void> _fetchModels() async {
    if (_selectedApiKeyId == null) return;

    setState(() {
      _isLoadingModels = true;
      _availableModels = [];
      _availableVisionModels = [];
    });

    try {
      final apiKeyValue = await ref.read(apiKeysProvider.notifier).getApiKeyValue(_selectedApiKeyId!);
      if (apiKeyValue == null) return;

      final profile = ProviderProfile(
        id: 'temp',
        name: 'temp',
        providerType: _providerType,
        apiKeyId: _selectedApiKeyId,
        model: 'placeholder',
        baseUrl: _baseUrlController.text.trim().isEmpty ? null : _baseUrlController.text.trim(),
      );

      TranslationProvider provider;
      if (_providerType == ProviderType.openrouter) {
        provider = OpenRouterProvider.fromProfile(profile: profile, apiKey: apiKeyValue);
      } else if (_providerType == ProviderType.gemini) {
        provider = GeminiProvider(apiKey: apiKeyValue, model: 'placeholder');
      } else {
        provider = OpenAICompatibleProvider(
          apiKey: apiKeyValue,
          baseUrl: _baseUrlController.text.trim().isEmpty ? 'http://localhost:11434/v1' : _baseUrlController.text.trim(),
        );
      }

      final models = await provider.fetchModels();

      if (!mounted) return;

      setState(() {
        _availableModels = models;
        _availableVisionModels = models;
        _isLoadingModels = false;

        if (_selectedModel != null && !models.contains(_selectedModel)) {
          _selectedModel = models.isNotEmpty ? models.first : null;
        }
        if (_selectedVisionModel != null && !models.contains(_selectedVisionModel)) {
          _selectedVisionModel = models.isNotEmpty ? models.first : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingModels = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileLoadModelsFailed('$e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectModel() async {
    if (!_canFetchModels || _availableModels.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final result = await showSelectionModal<String>(
      context: context,
      title: l10n.profileSelectModelTitle,
      options: _availableModels
          .map((m) => SelectionOption<String>(value: m, label: m))
          .toList(),
      selectedValue: _selectedModel,
      searchHint: l10n.profileSearchModelsHint,
    );
    if (result != null) {
      setState(() => _selectedModel = result);
    }
  }

  Future<void> _selectVisionModel() async {
    if (!_canFetchModels || _availableVisionModels.isEmpty) return;

    final l10n = AppLocalizations.of(context);
    final result = await showSelectionModal<String>(
      context: context,
      title: l10n.profileSelectVisionModelTitle,
      options: _availableVisionModels
          .map((m) => SelectionOption<String>(value: m, label: m))
          .toList(),
      selectedValue: _selectedVisionModel,
      searchHint: l10n.profileSearchModelsHint,
    );
    if (result != null) {
      setState(() => _selectedVisionModel = result);
    }
  }

  Future<void> _selectApiKey() async {
    final apiKeys = ref.read(apiKeysProvider);
    final options = apiKeys
        .map((k) => SelectionOption<String>(value: k.id, label: k.name))
        .toList();

    if (options.isEmpty) {
      // No keys exist yet: take the user directly to the keys manager
      // instead of showing a dead-end snackbar.
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ApiKeysScreen(),
          fullscreenDialog: true,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
    final result = await showSelectionModal<String>(
      context: context,
      title: l10n.profileSelectApiKeyTitle,
      options: options,
      selectedValue: _selectedApiKeyId,
    );
    if (result != null && result != _selectedApiKeyId) {
      setState(() {
        _selectedApiKeyId = result;
        _availableModels = [];
        _availableVisionModels = [];
        _selectedModel = null;
        _selectedVisionModel = null;
      });
      _fetchModels();
    }
  }

  Future<void> _selectFallbackApiKey() async {
    final l10n = AppLocalizations.of(context);
    final apiKeys = ref.read(apiKeysProvider);
    final options = <SelectionOption<String>>[
      SelectionOption<String>(value: '', label: l10n.settingsNoneOption),
      ...apiKeys.map((k) => SelectionOption<String>(value: k.id, label: k.name)),
    ];

    final result = await showSelectionModal<String>(
      context: context,
      title: l10n.profileSelectFallbackApiKeyTitle,
      options: options,
      selectedValue: _selectedFallbackApiKeyId ?? '',
    );
    setState(() {
      _selectedFallbackApiKeyId = result?.isEmpty == true ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiKeys = ref.watch(apiKeysProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.profileEditTitle : l10n.profileNewTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.commonName,
              hintText: l10n.profileNameHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Text(l10n.profileProviderTypeLabel, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<ProviderType>(
            segments: [
              ButtonSegment(
                value: ProviderType.openrouter,
                label: const Text('OpenRouter'),
                icon: const Icon(Icons.route, size: 18),
              ),
              ButtonSegment(
                value: ProviderType.gemini,
                label: const Text('Gemini'),
                icon: const Icon(Icons.auto_awesome, size: 18),
              ),
              ButtonSegment(
                value: ProviderType.openaiCompatible,
                label: const Text('OpenAI'),
                icon: const Icon(Icons.settings_ethernet, size: 18),
              ),
            ],
            selected: {_providerType},
            onSelectionChanged: (types) {
              setState(() {
                _providerType = types.first;
                _availableModels = [];
                _availableVisionModels = [];
                _selectedModel = null;
                _selectedVisionModel = null;
              });
            },
          ),
          const SizedBox(height: 16),

          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.profileModelLabel,
              border: const OutlineInputBorder(),
              suffixIcon: _isLoadingModels
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _canFetchModels
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedApiKeyId != null)
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: _isLoadingModels ? null : _fetchModels,
                                tooltip: l10n.profileRefreshModelsTooltip,
                              ),
                          ],
                        )
                      : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _canFetchModels ? _selectModel : _showModelAccessDialog,
              child: Text(
                _selectedModel ??
                    (_canFetchModels
                        ? l10n.profileSelectModelHint
                        : l10n.profileSelectApiKeyFirstHint),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _selectedModel == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.profileVisionModelLabel,
              border: const OutlineInputBorder(),
              suffixIcon: _canFetchModels && _selectedApiKeyId != null
                  ? IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _isLoadingModels ? null : _fetchModels,
                      tooltip: l10n.profileRefreshModelsTooltip,
                    )
                  : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _canFetchModels ? _selectVisionModel : _showModelAccessDialog,
              child: Text(
                _selectedVisionModel ??
                    (_canFetchModels
                        ? l10n.profileVisionModelPlaceholder
                        : l10n.profileSelectApiKeyFirstHint),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _selectedVisionModel == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.profileApiKeyLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: _apiKeyHighlight
                    ? BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      )
                    : BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: _apiKeyHighlight
                    ? BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      )
                    : BorderSide(color: theme.colorScheme.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: _apiKeyHighlight
                    ? BorderSide(
                        color: theme.colorScheme.error,
                        width: 2,
                      )
                    : BorderSide(color: theme.colorScheme.outline),
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _selectApiKey,
              child: Text(
                _selectedApiKeyId != null
                    ? apiKeys.firstWhere((k) => k.id == _selectedApiKeyId).name
                    : l10n.settingsNoneOption,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _selectedApiKeyId == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.profileFallbackApiKeyLabel,
              border: const OutlineInputBorder(),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _selectFallbackApiKey,
              child: Text(
                _selectedFallbackApiKeyId != null
                    ? apiKeys
                        .firstWhere((k) => k.id == _selectedFallbackApiKeyId)
                        .name
                    : l10n.settingsNoneOption,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _selectedFallbackApiKeyId == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_providerType == ProviderType.openaiCompatible) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text(
              l10n.profileOpenAiSettingsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(
                labelText: l10n.profileBaseUrlLabel,
                hintText: 'http://localhost:11434/v1',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveProfile,
        icon: const Icon(Icons.save),
        label: Text(l10n.commonSave),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileNameRequired)),
      );
      return;
    }

    final model = _selectedModel;
    if (model == null || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileModelRequired)),
      );
      return;
    }

    // Custom endpoints must use HTTPS unless they point at a loopback
    // address (localhost / 127.0.0.1 / [::1]) — those are the only
    // cleartext exceptions, for local models such as Ollama.
    if (_providerType == ProviderType.openaiCompatible) {
      final raw = _baseUrlController.text.trim();
      if (raw.isNotEmpty) {
        final verdict = validateProviderBaseUrl(raw);
        if (verdict is! BaseUrlOk) {
          final message = switch (verdict) {
            BaseUrlMalformed() => l10n.profileBaseUrlHttpsHint,
            BaseUrlBadScheme() => l10n.profileBaseUrlInvalid,
            BaseUrlInsecureRemote() => l10n.profileBaseUrlHttpsRequired,
            BaseUrlOk() => '', // unreachable — handled above
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          return;
        }
      }
    }

    final id = _isEditing
        ? widget.profile!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final profile = ProviderProfile(
      id: id,
      name: name,
      providerType: _providerType,
      apiKeyId: _selectedApiKeyId,
      fallbackApiKeyId: _selectedFallbackApiKeyId,
      model: model,
      visionModel: _selectedVisionModel,
      baseUrl: _providerType == ProviderType.openaiCompatible
          ? _baseUrlController.text.trim().isEmpty
                ? null
                : _baseUrlController.text.trim()
          : null,
      isBuiltIn: _isEditing ? widget.profile!.isBuiltIn : false,
    );

    await ref.read(profilesProvider.notifier).saveProfile(profile);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
