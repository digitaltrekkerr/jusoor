import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_core/translation_core.dart';

import '../providers/settings_provider.dart';
import '../widgets/selection_modal.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final ProviderProfile? profile;

  const ProfileEditScreen({super.key, this.profile});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
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
    super.dispose();
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
          SnackBar(content: Text('Failed to load models: $e')),
        );
      }
    }
  }

  Future<void> _selectModel() async {
    if (!_canFetchModels || _availableModels.isEmpty) return;

    final result = await showSelectionModal<String>(
      context: context,
      title: 'Select Model',
      options: _availableModels
          .map((m) => SelectionOption<String>(value: m, label: m))
          .toList(),
      selectedValue: _selectedModel,
      searchHint: 'Search models...',
    );
    if (result != null) {
      setState(() => _selectedModel = result);
    }
  }

  Future<void> _selectVisionModel() async {
    if (!_canFetchModels || _availableVisionModels.isEmpty) return;

    final result = await showSelectionModal<String>(
      context: context,
      title: 'Select Vision Model',
      options: _availableVisionModels
          .map((m) => SelectionOption<String>(value: m, label: m))
          .toList(),
      selectedValue: _selectedVisionModel,
      searchHint: 'Search models...',
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No API keys available. Add one in Settings.')),
      );
      return;
    }

    final result = await showSelectionModal<String>(
      context: context,
      title: 'Select API Key',
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
    final apiKeys = ref.read(apiKeysProvider);
    final options = <SelectionOption<String>>[
      const SelectionOption<String>(value: '', label: '(None)'),
      ...apiKeys.map((k) => SelectionOption<String>(value: k.id, label: k.name)),
    ];

    final result = await showSelectionModal<String>(
      context: context,
      title: 'Select Fallback API Key',
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

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Profile' : 'New Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. My OpenRouter Profile',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Text('Provider Type', style: theme.textTheme.titleSmall),
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
              labelText: 'Model',
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
                                tooltip: 'Refresh models',
                              ),
                          ],
                        )
                      : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _canFetchModels ? _selectModel : null,
              child: Text(
                _selectedModel ?? (_canFetchModels ? 'Select a model' : 'Select API key first'),
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
              labelText: 'Vision Model (optional)',
              border: const OutlineInputBorder(),
              suffixIcon: _canFetchModels && _selectedApiKeyId != null
                  ? IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _isLoadingModels ? null : _fetchModels,
                      tooltip: 'Refresh models',
                    )
                  : null,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _canFetchModels ? _selectVisionModel : null,
              child: Text(
                _selectedVisionModel ?? (_canFetchModels ? 'For image translation' : 'Select API key first'),
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
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _selectApiKey,
              child: Text(
                _selectedApiKeyId != null
                    ? apiKeys.firstWhere((k) => k.id == _selectedApiKeyId).name
                    : '(None)',
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
            decoration: const InputDecoration(
              labelText: 'Fallback API Key (optional)',
              border: OutlineInputBorder(),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _selectFallbackApiKey,
              child: Text(
                _selectedFallbackApiKeyId != null
                    ? apiKeys.firstWhere((k) => k.id == _selectedFallbackApiKeyId).name
                    : '(None)',
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
              'OpenAI-Compatible Settings',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://localhost:11434/v1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveProfile,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name is required.')),
      );
      return;
    }

    final model = _selectedModel;
    if (model == null || model.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Model selection is required.')));
      return;
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
