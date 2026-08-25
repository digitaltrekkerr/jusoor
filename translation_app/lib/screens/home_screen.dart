import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_handler/file_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translation_core/translation_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/share_intent_provider.dart';
import '../providers/translation_provider.dart';
import '../services/share_intent_handler.dart';
import '../widgets/bidi_markdown_view.dart';
import '../widgets/language_dropdown.dart';

/// Main translation screen with input, language selectors, and output.
///
/// Displays template selectors at the top, followed by language selectors,
/// input area, action buttons, and output area.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates the [HomeScreen].
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _inputController = TextEditingController();
  String _imageBase64 = '';
  String? _imageMimeType;
  Uint8List? _imageBytes;

  /// Cached word count of the input text.
  ///
  /// Recomputed only when the text actually changes instead of on every
  /// rebuild. During a streaming translation the whole screen rebuilds for
  /// each flushed chunk; recomputing here would resplit a large input
  /// document on every update.
  int _cachedWordCount = 0;

  /// Flag to prevent re-processing the same shared content when the widget
  /// rebuilds due to an unrelated state change.
  SharedContent? _lastProcessedContent;

  @override
  void initState() {
    super.initState();
    // Track the input word count. The controller notifies on direct text
    // assignment (shared content, file upload, paste) so no call sites are
    // skipped.
    _inputController.addListener(_syncInputWordCount);
    // Listen for shared content changes and process them once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processSharedContent();
    });
  }

  @override
  void dispose() {
    _inputController.removeListener(_syncInputWordCount);
    _inputController.dispose();
    super.dispose();
  }

  void _syncInputWordCount() {
    _cachedWordCount = WordCounter.count(_inputController.text);
  }

  // ── Shared content handling ──────────────────────────────────────────

  /// Processes the current shared content from [sharedContentProvider].
  Future<void> _processSharedContent() async {
    final content = ref.read(sharedContentProvider);
    if (content == null || content == _lastProcessedContent) return;
    _lastProcessedContent = content;

    if (content.hasImage) {
      setState(() {
        _imageBytes = content.imageBytes;
        _imageBase64 = base64Encode(content.imageBytes!);
        _imageMimeType = 'image/jpeg';
      });
      ref.read(sharedContentProvider.notifier).clear();
      return;
    }

    String? textToInsert;

    if (content.hasText) {
      textToInsert = content.text;
    } else if (content.hasFile) {
      final handler = ref.read(shareIntentHandlerProvider);
      final parsed = await handler.parseSharedFile(content);
      if (parsed.hasImage) {
        setState(() {
          _imageBytes = parsed.imageBytes;
          _imageBase64 = base64Encode(parsed.imageBytes!);
          _imageMimeType = 'image/jpeg';
        });
        ref.read(sharedContentProvider.notifier).clear();
        return;
      }
      textToInsert = parsed.text;
    }

    if (textToInsert == null || textToInsert.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).homeErrorSharedContent,
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      ref.read(sharedContentProvider.notifier).clear();
      return;
    }

    setState(() {
      _inputController.text = textToInsert!;
    });

    ref.read(sharedContentProvider.notifier).clear();
  }

  // ── Word count ─────────────────────────────────────────────────────

  int get _wordCount => _cachedWordCount;

  // ── Handlers ───────────────────────────────────────────────────────

  Future<void> _handleTranslate() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty && _imageBase64.isEmpty) return;

    final wordLimit = ref.read(wordLimitProvider);
    if (_wordCount > wordLimit) {
      final proceed = await _showWordLimitDialog(_wordCount, wordLimit);
      if (!proceed) return;
    }

    final targetLang = ref.read(targetLanguageProvider);

    final request = TranslationRequest(
      inputText: inputText,
      targetLanguage: targetLang,
      imageBase64: _imageBase64.isEmpty ? null : _imageBase64,
      imageMimeType: _imageBase64.isNotEmpty ? _imageMimeType : null,
      wordCount: _wordCount,
    );

    await ref.read(translationProvider.notifier).translate(request);
  }

  Future<bool> _showWordLimitDialog(int count, int limit) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homeWordLimitTitle),
        content: Text(l10n.homeWordLimitBody(count, limit)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.appCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.appProceed),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handlePickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    final extension = xFile.name.split('.').last.toLowerCase();
    final mimeType = _mimeTypeFromExtension(extension);
    setState(() {
      _imageBytes = bytes;
      _imageBase64 = base64Encode(bytes);
      _imageMimeType = mimeType;
    });
  }

  Future<void> _handleUploadFile() async {
    final pickerService = FilePickerService();
    final picked = await pickerService.pickFile();

    if (picked == null) return;
    if (picked.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).homeErrorFileBytes,
            ),
          ),
        );
      }
      return;
    }

    final content = utf8.decode(picked.bytes!, allowMalformed: true);
    final parsed = ParserFactory.parse(content, picked.extension);

    // Show info banner if text is large
    final wordCount = WordCounter.count(parsed);
    final wordLimit = ref.read(wordLimitProvider);
    if (wordCount > wordLimit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).homeFileWillBeChunked,
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _inputController.text = parsed;
    });
  }

  void _handleClear() {
    _inputController.clear();
    setState(() {
      _imageBytes = null;
      _imageBase64 = '';
      _imageMimeType = null;
    });
    ref.read(translationProvider.notifier).reset();
  }

  Future<void> _handleShare() async {
    final state = ref.read(translationProvider);
    if (state is! TranslationDone) return;

    final l10n = AppLocalizations.of(context);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/translation_$timestamp.md');
    try {
      await file.writeAsString(state.fullText);

      await SharePlus.instance.share(
        ShareParams(
          text: l10n.homeShareText,
          subject: l10n.homeShareSubject,
          files: [XFile(file.path)],
        ),
      );
    } finally {
      // Clean up the temp file
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static String _mimeTypeFromExtension(String ext) {
    return switch (ext.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/jpeg',
    };
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Listen for new shared content arriving while this screen is mounted.
    ref.listen<SharedContent?>(sharedContentProvider, (previous, next) {
      if (next != null && next != _lastProcessedContent) {
        _processSharedContent();
      }
    });

    final translationState = ref.watch(translationProvider);
    final isTranslating =
        translationState is TranslationLoading ||
        translationState is TranslationStreaming;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Template selectors ─────────────────────────────────
              _TemplateSelectorRow(),
              const SizedBox(height: 16),

              // ── Language selectors ─────────────────────────────────
              _LanguageSelectorRow(),
              const SizedBox(height: 16),

              // ── Input area ─────────────────────────────────────────
              _InputArea(
                controller: _inputController,
                imageBytes: _imageBytes,
                wordCount: _wordCount,
                onPickImage: _handlePickImage,
                onUploadFile: _handleUploadFile,
                onRemoveImage: () {
                  setState(() {
                    _imageBytes = null;
                    _imageBase64 = '';
                    _imageMimeType = null;
                  });
                },
                onTextChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // ── Action buttons ──────────────────────────────────────
              _ActionButtons(
                isTranslating: isTranslating,
                hasInput:
                    _inputController.text.isNotEmpty || _imageBase64.isNotEmpty,
                onTranslate: _handleTranslate,
                onCancel: () => ref.read(translationProvider.notifier).cancel(),
                onClear: _handleClear,
                onShare: _handleShare,
                canShare: translationState is TranslationDone,
              ),
              const SizedBox(height: 16),

              // ── Output area ────────────────────────────────────────
              _OutputArea(state: translationState),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Template selector row ────────────────────────────────────────────

/// Row with two template selectors: one for text, one for image.
///
/// Each selector shows the currently selected template name + profile name.
/// On tap, shows a bottom sheet with templates grouped by profile.
class _TemplateSelectorRow extends ConsumerWidget {
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
          child: _TemplateSelectorChip(
            icon: Icons.text_fields,
            label: textLabel,
            profileName: textProfileName,
            onTap: () =>
                _showTemplatePicker(context, ref, supportsImage: false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TemplateSelectorChip(
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
class _TemplateSelectorChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? profileName;
  final VoidCallback onTap;

  const _TemplateSelectorChip({
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

// ── Language selector ────────────────────────────────────────────────

/// Target-language dropdown for the home screen.
///
/// A single language selector; the two-column grid lives inside the
/// selection modal ([LanguageDropdown] / `SelectionModal`).
class _LanguageSelectorRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final targetLang = ref.watch(targetLanguageProvider);

    return Semantics(
      label: l10n.langRow_targetTooltip,
      container: true,
      child: LanguageDropdown(
        selected: targetLang,
        onChanged: (v) => ref.read(targetLanguageProvider.notifier).set(v),
        hintText: l10n.homeTargetLanguageHint,
      ),
    );
  }
}

// ── Input area ───────────────────────────────────────────────────────

class _InputArea extends StatefulWidget {
  final TextEditingController controller;
  final Uint8List? imageBytes;
  final int wordCount;
  final VoidCallback onPickImage;
  final VoidCallback onUploadFile;
  final VoidCallback onRemoveImage;
  final ValueChanged<String> onTextChanged;

  const _InputArea({
    required this.controller,
    required this.imageBytes,
    required this.wordCount,
    required this.onPickImage,
    required this.onUploadFile,
    required this.onRemoveImage,
    required this.onTextChanged,
  });

  @override
  State<_InputArea> createState() => _InputAreaState();
}

class _InputAreaState extends State<_InputArea> {
  TextDirection _inputDirection = TextDirection.ltr;
  bool _hasClipboardContent = false;
  Timer? _clipboardCheckTimer;
  bool _needsInitialDetection = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    // Android 14+ (API 34) shows a toast on every clipboard read, so avoid
    // periodic polling. The manual paste button is always available.
    if (!Platform.isAndroid) {
      _clipboardCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkClipboard(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_needsInitialDetection) {
      _needsInitialDetection = false;
      _inputDirection = BiDiMarkdownView.detectDirection(
        widget.controller.text,
        fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _clipboardCheckTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final newDir = BiDiMarkdownView.detectDirection(
      widget.controller.text,
      fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      previous: _inputDirection,
    );
    if (newDir != _inputDirection) {
      _inputDirection = newDir;
    }
    setState(() {});
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (mounted) {
        setState(() {
          _hasClipboardContent =
              data != null && data.text != null && data.text!.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!;
        final selection = widget.controller.selection;
        int start = selection.start;
        int end = selection.end;
        final textLength = widget.controller.text.length;
        if (start < 0) start = textLength;
        if (end < 0) end = textLength;
        if (start > end) {
          final temp = start;
          start = end;
          end = temp;
        }
        if (start > textLength) start = textLength;
        if (end > textLength) end = textLength;
        final newText =
            widget.controller.text.replaceRange(start, end, text);
        widget.controller.text = newText;
        widget.onTextChanged(newText);
        widget.controller.selection = TextSelection.collapsed(
          offset: start + text.length,
        );
        _inputDirection = BiDiMarkdownView.detectDirection(
          widget.controller.text,
          fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
          previous: _inputDirection,
        );
        await _checkClipboard();
      }
    } catch (e) {
      debugPrint('[InputArea] Paste error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: 8,
          textDirection: _inputDirection,
          textAlign: _inputDirection == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,
          decoration: InputDecoration(
            hintText: l10n.homeInputHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: widget.controller.text.isEmpty && _hasClipboardContent
                ? IconButton(
                    icon: const Icon(Icons.paste, size: 18),
                    tooltip: l10n.homePasteTooltip,
                    onPressed: _pasteFromClipboard,
                  )
                : null,
          ),
          onChanged: (value) {
            widget.onTextChanged(value);
            final newDir = BiDiMarkdownView.detectDirection(
              value,
              fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
              previous: _inputDirection,
            );
            if (newDir != _inputDirection) {
              setState(() { _inputDirection = newDir; });
            }
          },
        ),
        if (widget.imageBytes != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _ImageThumbnail(
              imageBytes: widget.imageBytes!,
              onRemove: widget.onRemoveImage,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              l10n.homeWordCount(widget.wordCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            IconButton.outlined(
              icon: const Icon(Icons.image_outlined, size: 20),
              tooltip: l10n.homePickImageTooltip,
              onPressed: widget.onPickImage,
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              icon: const Icon(Icons.attach_file, size: 20),
              tooltip: l10n.homeUploadFileTooltip,
              onPressed: widget.onUploadFile,
            ),
          ],
        ),
      ],
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final Uint8List imageBytes;
  final VoidCallback onRemove;

  const _ImageThumbnail({
    required this.imageBytes,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Action buttons ───────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final bool isTranslating;
  final bool hasInput;
  final VoidCallback onTranslate;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final bool canShare;

  const _ActionButtons({
    required this.isTranslating,
    required this.hasInput,
    required this.onTranslate,
    required this.onCancel,
    required this.onClear,
    required this.onShare,
    required this.canShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: !hasInput
                ? null
                : isTranslating
                    ? onCancel
                    : onTranslate,
            icon: isTranslating
                ? const Icon(Icons.close)
                : const Icon(Icons.translate),
            label: Text(
              isTranslating ? l10n.appCancel : l10n.homeTranslateButton,
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.clear, size: 18),
          label: Text(l10n.homeClearButton),
        ),
        if (canShare) ...[
          const SizedBox(width: 8),
          IconButton.outlined(
            icon: const Icon(Icons.share),
            tooltip: l10n.homeShareTooltip,
            onPressed: onShare,
          ),
        ],
      ],
    );
  }
}

// ── Output area ──────────────────────────────────────────────────────

class _OutputArea extends StatelessWidget {
  final TranslationState state;

  const _OutputArea({required this.state});

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).homeCopiedToClipboard),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (state) {
        TranslationIdle() => const SizedBox(key: ValueKey('idle')),
        TranslationLoading() => const BiDiMarkdownView.loading(key: ValueKey('loading')),
        TranslationStreaming(:final partial) => Column(
          key: const ValueKey('streaming'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l10n.homeOutputTitle, style: theme.textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: l10n.homeCopyTooltip,
                  onPressed: () => _copyText(context, partial),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BiDiMarkdownView.streaming(partial: partial, selectable: true),
          ],
        ),
        TranslationDone(:final fullText, :final modelUsed, :final durationMs) =>
          Column(
            key: const ValueKey('done'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(l10n.homeOutputTitle, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: l10n.homeCopyTooltip,
                    onPressed: () => _copyText(context, fullText),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.homeModelInfo(modelUsed, durationMs ~/ 1000),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              BiDiMarkdownView(markdownText: fullText, selectable: true),
            ],
          ),
        TranslationError(:final message) => Container(
          key: const ValueKey('error'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}
