import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_handler/file_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown_renderer/markdown_renderer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:translation_core/translation_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../providers/share_intent_provider.dart';
import '../providers/translation_provider.dart';
import '../services/deferred_temp_file_cleanup.dart';
import '../services/share_intent_handler.dart';
import '../widgets/home_action_buttons.dart';
import '../widgets/home_input_area.dart';
import '../widgets/home_language_selector.dart';
import '../widgets/home_output_area.dart';
import '../widgets/home_template_selector.dart';
import '../utils/image_payload.dart';

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

  /// Stores an image for translation, resizing it on the way in.
  ///
  /// Every image entering the app goes through here so the limits are
  /// enforced once. OpenRouter routes image requests to the provider of
  /// your choice, and those providers disagree sharply on what they accept:
  /// OpenAI-style gateways silently downscale an oversized image, while
  /// Anthropic rejects it outright — a full-screen PNG screenshot cleared
  /// Anthropic's limit and failed with a bare HTTP 400 on a Claude model
  /// while working fine on a GPT one.
  ///
  /// [ImagePayloadPreparer] caps the long edge at 1568 px, which also caps
  /// the token cost at Anthropic's standard resolution tier.
  Future<void> _setImage(Uint8List bytes, String? mimeType) async {
    final prepared = await ImagePayloadPreparer.prepare(
      bytes,
      mimeType: mimeType,
    );
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageBase64 = prepared.base64;
      _imageMimeType = prepared.mimeType;
    });
  }

  /// Processes the current shared content from [sharedContentProvider].
  Future<void> _processSharedContent() async {
    final content = ref.read(sharedContentProvider);
    if (content == null || content == _lastProcessedContent) return;
    _lastProcessedContent = content;

    if (content.hasImage) {
      await _setImage(content.imageBytes!, 'image/jpeg');
      ref.read(sharedContentProvider.notifier).clear();
      return;
    }

    String? textToInsert;

    if (content.hasText) {
      textToInsert = content.text;
    } else if (content.hasFile) {
      final handler = ref.read(shareIntentHandlerProvider);
      SharedContent parsed;
      try {
        parsed = await handler.parseSharedFile(content);
      } on SharedFileTooLargeException {
        // OOM guard: refuse files over the 50 MB ceiling with a clear
        // message instead of crashing while reading them into memory.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).shareFileTooLarge,
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        ref.read(sharedContentProvider.notifier).clear();
        return;
      }
      if (parsed.hasImage) {
        await _setImage(parsed.imageBytes!, 'image/jpeg');
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

  /// Returns the currently selected text template, or `null` when none is
  /// chosen or the id no longer resolves.
  PromptTemplate? get _selectedTextTemplate {
    final id = ref.watch(selectedTextTemplateProvider);
    if (id == null) return null;
    final templates = ref.watch(templatesProvider);
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// True when the selected text template locks the output language
  /// (no `{{target_language}}` substitution). When true, the language
  /// selector on the home screen is hidden because the template bakes the
  /// target language into its prompt.
  bool get _isSelectedTemplateFixedLanguage {
    final template = _selectedTextTemplate;
    return template?.outputLanguageFixed == true;
  }

  // ── Handlers ───────────────────────────────────────────────────────

  Future<void> _handleTranslate() async {
    final inputText = _inputController.text.trim();
    if (inputText.isEmpty && _imageBase64.isEmpty) return;

    final wordLimit = ref.read(wordLimitProvider);
    if (_wordCount > wordLimit) {
      final proceed = await _showWordLimitDialog(_wordCount, wordLimit);
      if (!proceed) return;
    }

    // A fixed-language template hides the language selector only to prevent
    // mid-typing changes — its prompt still resolves `{{target_language}}`
    // from the user's persisted default target language. Passing the 'auto'
    // sentinel here made the prompt read "translate to auto" and the model
    // echoed the source text unchanged, so always send the persisted value.
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
    await _setImage(bytes, _mimeTypeFromExtension(extension));
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
    ref.read(translationProvider.notifier).clearAll();
  }

  Future<void> _handleShare() async {
    final state = ref.read(translationProvider);
    if (state is! TranslationDone) return;
    await _showShareOptions(state.fullText);
  }

  /// Shows a bottom sheet with three share options:
  /// 1. Share as plain text (Markdown stripped).
  /// 2. Share as a Markdown `.md` file (the existing behaviour).
  /// 3. Save to a downloadable file (user picks the destination).
  Future<void> _showShareOptions(String text) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.shareOptionsTitle,
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: Text(l10n.shareAsPlain),
              subtitle: Text(l10n.sheetPlainSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await SharePlus.instance.share(
                  ShareParams(text: toPlainText(text)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.shareAsMarkdown),
              subtitle: Text(l10n.sheetMarkdownFileSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _shareAsMarkdown(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.saveToFile),
              subtitle: Text(l10n.sheetSaveToFileSubtitle),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _saveToDownloads(text);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Writes [text] to a temporary `.md` file and opens the share sheet.
  ///
  /// Preserved from the original single-mode share behaviour.
  Future<void> _shareAsMarkdown(String text) async {
    // Capture l10n before any await so we don't need context after async
    // gaps in this helper.
    final l10n = AppLocalizations.of(context);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${tempDir.path}/translation_$timestamp.md');
    try {
      await file.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(
          text: l10n.homeShareText,
          subject: l10n.homeShareSubject,
          files: [XFile(file.path)],
        ),
      );
    } finally {
      // Never delete here: the share target may still be reading the file
      // after the sheet closes. Deletion is deferred by a grace period so
      // the receiving app always grabs a live file.
      DeferredTempFileCleanup.instance.scheduleDeletion(file.path);
    }
  }

  /// Writes [text] to a `.md` file in the temp directory and opens the
  /// share sheet with the file attached so the user can pick the final
  /// destination (Downloads, Drive, Telegram, etc.) without the app
  /// requiring `WRITE_EXTERNAL_STORAGE`.
  Future<void> _saveToDownloads(String text) async {
    // Capture l10n before any await so we don't need context after async
    // gaps in this helper.
    final l10n = AppLocalizations.of(context);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${tempDir.path}/jusoor_translation_$timestamp.md',
    );
    try {
      await file.writeAsString(text);
      await SharePlus.instance.share(
        ShareParams(
          text: l10n.homeShareText,
          subject: l10n.homeShareSubject,
          files: [XFile(file.path)],
        ),
      );
    } finally {
      // Deferred cleanup: keeps the file alive while the share target reads
      // it, then removes it after a grace period.
      DeferredTempFileCleanup.instance.scheduleDeletion(file.path);
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
    final notifier = ref.read(translationProvider.notifier);
    final isRunning =
        translationState is TranslationLoading ||
        translationState is TranslationStreaming;
    // State is authoritative because the generation guard forbids a stale run
    // from writing state; the live-token check keeps a spent token from ever
    // enabling Cancel again.
    final canCancel = isRunning && notifier.hasLiveRequest;
    final canTranslate = !isRunning &&
        (_inputController.text.isNotEmpty || _imageBase64.isNotEmpty);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Template selectors ─────────────────────────────────
              TemplateSelectorRow(),
              const SizedBox(height: 16),

              // ── Language selectors ─────────────────────────────────
              // Hide when the selected text template locks the output
              // language (it bakes the target language into the prompt
              // via `{{target_language}} = <fixed>`).
              Visibility(
                visible: !_isSelectedTemplateFixedLanguage,
                maintainState: true,
                child: LanguageSelectorRow(),
              ),
              const SizedBox(height: 16),

              // ── Input area ─────────────────────────────────────────
              InputArea(
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
              ActionButtons(
                isRunning: isRunning,
                canCancel: canCancel,
                canTranslate: canTranslate,
                canClear: true,
                onTranslate: _handleTranslate,
                onCancel: () => ref.read(translationProvider.notifier).cancel(),
                onClear: _handleClear,
                onShare: _handleShare,
                canShare: translationState is TranslationDone,
              ),
              const SizedBox(height: 16),

              // ── Output area ────────────────────────────────────────
              OutputArea(state: translationState),
            ],
          ),
        ),
      ),
    );
  }
}

