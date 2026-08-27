import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:history/history.dart';
import 'package:markdown_renderer/markdown_renderer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_core/translation_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'l10n/app_localizations.dart';
import 'overlay/overlay_utils.dart';
import 'providers/settings_provider.dart';
import 'providers/translation_provider.dart';
import 'services/deferred_temp_file_cleanup.dart';
import 'services/settings_repository.dart';
import 'utils/overlay_template_guard.dart';
import 'utils/overlay_theme.dart';
import 'widgets/bidi_markdown_view.dart';
import 'widgets/language_dropdown.dart';

const Color _kSeedColor = Color(0xFF4F46E5);
const String _kSelectedOverlayTemplatePref = 'selected_overlay_template';
const String _kDefaultTargetLanguageKey = 'default_target_language';
const String _kOverlaySelectedLanguageKey = 'overlay_selected_language';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugPrint('[OverlayMain] WidgetsFlutterBinding initialized');
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.red.shade900,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Overlay Error: ${details.exception}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  };

  runApp(const _OverlayApp());
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> with WidgetsBindingObserver {
  /// Current overlay theme mode.
  ///
  /// Starts at [ThemeMode.system] (tracks the device) so the very first
  /// frame never flashes a wrong theme while the persisted pref loads, then
  /// follows the app's setting live. The overlay runs in a SEPARATE Flutter
  /// engine/isolate from the main app, so Riverpod provider state is not
  /// shared here: this notifier is fed from three sources —
  ///  1. the persisted pref, re-read at startup and whenever the overlay
  ///     window (re)shows (`didChangeAppLifecycleState` → resumed),
  ///  2. a light poll timer that re-reads the pref every few seconds while
  ///     the overlay is mounted (guarantees convergence even if an IPC push
  ///     is missed), and
  ///  3. best-effort `theme_changed` IPC pushes from the app isolate
  ///     (`ThemeModeNotifier.set` in `settings_provider.dart`), handled in
  ///     `_TranslatorOverlayContentState` — the instant path while the
  ///     overlay is running.
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static const _overlayChannel = MethodChannel('x-slayer/overlay');

  /// How often the overlay re-reads the persisted theme pref as a live
  /// fallback. Cheap (one platform channel reload) and only notifies on
  /// actual change, so it never causes needless rebuilds.
  static const Duration _themePollInterval = Duration(seconds: 3);

  Timer? _themePollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshThemeFromPrefs();
    _themePollTimer = Timer.periodic(
      _themePollInterval,
      (_) => _refreshThemeFromPrefs(),
    );
  }

  @override
  void dispose() {
    _themePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _themeMode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The overlay's FlutterView re-attaches when the window is (re)shown;
    // re-read the persisted theme then so a change made while the overlay
    // was closed is applied immediately on show.
    if (state == AppLifecycleState.resumed) {
      _refreshThemeFromPrefs();
    }
  }

  /// Re-reads the persisted theme mode and applies it to [_themeMode].
  ///
  /// The overlay is a separate engine/isolate, so its in-memory
  /// [SharedPreferences] cache can be stale after the app isolate persisted
  /// a new mode — [SharedPreferences.reload] re-reads from the platform
  /// store on every call. Only notifies listeners when the value actually
  /// changed, so the poll never triggers rebuilds for no-op ticks.
  Future<void> _refreshThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final mode = resolveThemeMode(
        prefs.getString(SettingsRepository.themeModeKey),
      );
      if (!mounted) return;
      if (_themeMode.value != mode) {
        _themeMode.value = mode;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[OverlayMain] Failed to refresh theme mode, keeping current: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayThemeApp(
      themeMode: _themeMode,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            try {
              await _overlayChannel.invokeMethod('close');
            } catch (e) {
              if (kDebugMode) {
                debugPrint('[Overlay] Close error: $e');
              }
            }
          }
        },
        child: _TranslatorOverlayContent(themeModeNotifier: _themeMode),
      ),
    );
  }
}

class _TranslatorOverlayContent extends StatefulWidget {
  const _TranslatorOverlayContent({required this.themeModeNotifier});

  /// Live theme-mode source shared with [_OverlayApp]'s [OverlayThemeApp],
  /// so `theme_changed` IPC messages from the app isolate recolor the
  /// floating window immediately.
  final ValueNotifier<ThemeMode> themeModeNotifier;

  @override
  State<_TranslatorOverlayContent> createState() =>
      _TranslatorOverlayContentState();
}

class _TranslatorOverlayContentState extends State<_TranslatorOverlayContent> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  String _translatedText = '';
  String _selectedLanguageCode = 'en';
  String _selectedLanguageName = 'English';
  bool _isLoading = false;
  bool _isCancelling = false;
  TextDirection _inputDirection = TextDirection.ltr;
  bool _showCopiedFeedback = false;

  // Overlay palette resolved from the ambient theme so the floating window
  // follows the app's light/dark mode (previously hardcoded dark values).
  // Instance getters over [State.context] — valid during build only.
  Color get _primaryColor => Theme.of(context).colorScheme.primary;
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _surfaceContainerColor =>
      Theme.of(context).colorScheme.surfaceContainer;
  Color get _onSurfaceColor => Theme.of(context).colorScheme.onSurface;
  Color get _onSurfaceVariantColor =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  StreamSubscription<dynamic>? _overlaySubscription;
  bool _isCancelled = false;
  final HistoryService _historyService = HistoryService();
  bool _isFullMode = false;
  bool _needsInitialDetection = true;

  /// Aborts the in-flight overlay translation HTTP request when the user
  /// taps cancel. Set per translation run; `null` when idle.
  CancelToken? _translationCancelToken;

  /// Completer raced against the translation completion in
  /// [_runOverlayTranslation]. Completing it (on cancel) unblocks the await
  /// immediately so the UI reacts without waiting for the HTTP layer to
  /// notice the abort.
  Completer<void>? _cancelRaceCompleter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_needsInitialDetection) {
      _needsInitialDetection = false;
      _inputDirection = BiDiMarkdownView.detectDirection(
        _inputController.text,
        fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
  }

  bool get _canClear =>
      _inputController.text.isNotEmpty || _translatedText.isNotEmpty;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _overlayChannel.invokeMethod('focusable', {'enable': true});
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Overlay] Initial focus enable error: $e');
        }
      }
    });

    _loadDefaultLanguage();
    _loadSizeMode();

    _inputController.addListener(_onInputChanged);

    _inputFocusNode.addListener(() async {
      try {
        if (_inputFocusNode.hasFocus) {
          await _overlayChannel.invokeMethod('focusable', {'enable': true});
        } else {
          await _overlayChannel.invokeMethod('focusable', {'enable': false});
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Overlay] Focus update error: $e');
        }
      }
    });

    _overlaySubscription = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data == null) return;

      Map<String, dynamic> map;
      if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else if (data is String) {
        try {
          map = jsonDecode(data);
        } catch (e) {
          return;
        }
      } else {
        return;
      }

      if (kDebugMode) {
        debugPrint('[OverlayWidget] Received: ${map['type']}');
      }

      if (map['type'] == 'clear_state') {
        if (mounted) {
          setState(() {
            _inputController.clear();
            _translatedText = '';
            _isLoading = false;
          });
        }
      } else if (map['type'] == 'translation_result') {
        if (mounted) {
          final wasCancelled = map['cancelled'] == true;
          setState(() {
            _translatedText = wasCancelled
                ? ''
                : (map['result']?.toString() ?? 'Error');
            _isLoading = false;
            _isCancelling = false;
          });
        }
      } else if (map['type'] == 'theme_changed') {
        // Live theme push from the app isolate (see ThemeModeNotifier.set).
        // Best-effort: the overlay also re-reads the persisted pref on
        // (re)show and on a poll timer, so a missed push still converges.
        final raw = map['themeMode']?.toString();
        if (raw != null) {
          widget.themeModeNotifier.value = resolveThemeMode(raw);
        }
      }
    });
  }

  Future<void> _loadDefaultLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    String languageCode =
        prefs.getString(_kOverlaySelectedLanguageKey) ??
        prefs.getString(_kDefaultTargetLanguageKey) ??
        'Arabic';

    if (!_kLanguageNames.contains(languageCode)) {
      languageCode = 'Arabic';
    }

    final code = getLanguageCode(languageCode) ?? 'en';

    if (mounted) {
      setState(() {
        _selectedLanguageCode = code;
        _selectedLanguageName = languageCode;
      });
    }
  }

  Future<void> _loadSizeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('overlay_size_mode');
    if (mounted) {
      setState(() {
        _isFullMode = mode == 'full';
      });
    }
  }

  Future<void> _saveSelectedLanguage(String languageName, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOverlaySelectedLanguageKey, languageName);
  }

  void _onInputChanged() {
    final newDir = BiDiMarkdownView.detectDirection(
      _inputController.text,
      fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      previous: _inputDirection,
    );
    if (newDir != _inputDirection) {
      setState(() {
        _inputDirection = newDir;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    String? text;
    String source = '?';

    try {
      final result = await _overlayChannel
          .invokeMethod<Map>('readClipboard')
          .timeout(const Duration(seconds: 3));
      if (result != null) {
        final isStale = result['stale'] == true;
        text = result['text']?.toString();
        source = result['source']?.toString() ?? 'native';
        if (kDebugMode) {
          debugPrint(
            '[Overlay-Paste] Native clipboard: $source, ${text?.length ?? 0} chars',
          );
        }
        if (isStale && text != null && text.isNotEmpty) {
          _showOverlaySnackBar('Clipboard: ${text.length} chars (cached)');
        }
      }
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[Overlay-Paste] Native clipboard timed out');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Overlay-Paste] Native clipboard error: $e\n$st');
      }
    }

    if (text != null && text.isNotEmpty) {
      _insertAtCursor(text);
      if (kDebugMode) {
        debugPrint('[Overlay-Paste] Pasted via $source: ${text.length} chars');
      }
    } else {
      _showOverlaySnackBar('No text in clipboard');
    }
  }

  void _insertAtCursor(String text) {
    final selection = _inputController.selection;
    final textLength = _inputController.text.length;
    int start = selection.start;
    int end = selection.end;
    if (start < 0) start = textLength;
    if (end < 0) end = textLength;
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }
    if (start > textLength) start = textLength;
    if (end > textLength) end = textLength;
    final newText = _inputController.text.replaceRange(start, end, text);
    _inputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
  }

  static const _overlayChannel = MethodChannel('x-slayer/overlay');

  void _handleClose() async {
    _inputController.clear();
    setState(() {
      _translatedText = '';
      _isLoading = false;
    });

    try {
      await _overlayChannel.invokeMethod('close');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Close error: $e');
      }
    }
  }

  void _handleTranslate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _translatedText = '';
      _isCancelled = false;
      _isCancelling = false;
    });

    try {
      final result = await _performTranslation(text, _selectedLanguageCode);
      if (mounted) {
        setState(() {
          // `null` means the user cancelled — leave the output cleared.
          _translatedText = result ?? '';
        });
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        setState(() {
          _translatedText = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCancelling = false;
        });
      }
    }
  }

  void _handleCancel() async {
    setState(() {
      _isCancelled = true;
      _isCancelling = true;
    });

    // Direct overlay path: abort the HTTP request immediately and complete
    // the race completer so the awaiting [_runOverlayTranslation] returns
    // right away (no waiting for the next chunk).
    _translationCancelToken?.cancel();
    _cancelRaceCompleter?.complete();

    try {
      await FlutterOverlayWindow.shareData(
        jsonEncode({'type': 'cancel_translation'}),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Cancel signal error: $e');
      }
    }
  }

  void _handleScreenshot() async {
    if (_isCancelling) return;

    setState(() {
      _isLoading = true;
      _translatedText = '';
      _isCancelling = false;
    });

    try {
      final result = await _performScreenshotTranslation(_selectedLanguageCode);
      if (mounted) {
        setState(() {
          // `null` means the user cancelled — leave the output cleared.
          _translatedText = result ?? '';
        });
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        setState(() {
          _translatedText = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCancelled = false;
          _isCancelling = false;
        });
      }
    }
  }

  void _handleClear() {
    _inputController.clear();
    setState(() {
      _translatedText = '';
      _isLoading = false;
      _isCancelling = false;
      _isCancelled = false;
      _showCopiedFeedback = false;
    });
  }

  void _copyText(String text, {String mode = 'plain'}) {
    final processed = mode == 'markdown' ? text : toPlainText(text);
    _overlayChannel
        .invokeMethod('writeClipboard', {'text': processed, 'mode': mode})
        .then((_) {
          if (kDebugMode) {
            debugPrint(
              '[Overlay-Paste] Copied ($mode): ${processed.length} chars',
            );
          }
        })
        .catchError((e) {
          if (kDebugMode) {
            debugPrint('[Overlay-Paste] Copy error: $e');
          }
        });
    setState(() {
      _showCopiedFeedback = true;
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showCopiedFeedback = false;
        });
      }
    });
  }

  Future<void> _shareText(String text, {String mode = 'plain'}) async {
    try {
      if (mode == 'saveFile') {
        await _saveTranslationToFile(text);
        return;
      }
      final processed = mode == 'markdown' ? text : toPlainText(text);
      await SharePlus.instance.share(ShareParams(text: processed));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Share error: $e');
      }
    }
  }

  /// Writes [text] to a `.md` file in the temp directory and opens the
  /// share sheet with the file attached so the user can pick the final
  /// destination (Downloads, Drive, Telegram, etc.) without the overlay
  /// requiring `WRITE_EXTERNAL_STORAGE`.
  Future<void> _saveTranslationToFile(String text) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/jusoor_translation_$timestamp.md');
      try {
        await file.writeAsString(text);
        await SharePlus.instance.share(
          ShareParams(
            text: 'Jusoor translation',
            subject: 'Jusoor translation',
            files: [XFile(file.path)],
          ),
        );
      } finally {
        // Deferred cleanup: the share target may still be reading this
        // file after the sheet closes — deleting here races it.
        DeferredTempFileCleanup.instance.scheduleDeletion(file.path);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Save-to-file error: $e');
      }
    }
  }

  /// Resolves the app-UI language for the overlay sheets.
  ///
  /// The overlay runs in its own Flutter engine and cannot watch the main
  /// app's Riverpod providers, so the persisted `app_locale` pref is
  /// re-read (the same way the theme mode is). When the user has not
  /// chosen a language, the device locale is used — Arabic unless the
  /// device reports English — mirroring the main app's locale fallback.
  Future<AppLocalizations> _overlayL10n() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final code = prefs.getString('app_locale');
      if (code == AppLanguageCodes.english) {
        return lookupAppLocalizations(const Locale('en'));
      }
      if (code == AppLanguageCodes.arabic) {
        return lookupAppLocalizations(const Locale('ar'));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Failed to read app locale, falling back: $e');
      }
    }
    final device = Platform.localeName.toLowerCase();
    return lookupAppLocalizations(
      Locale(device.startsWith('en') ? 'en' : 'ar'),
    );
  }

  /// Shows a bottom sheet with three share options from the overlay:
  /// plain text, Markdown file, or save-to-file via the system share sheet.
  Future<void> _showShareOptions(String text) async {
    final l10n = await _overlayL10n();
    if (!mounted) return;
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
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _shareText(text, mode: 'plain');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.shareAsMarkdown),
              subtitle: Text(l10n.sheetMarkdownFileSubtitle),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _shareText(text, mode: 'markdown');
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: Text(l10n.saveToFile),
              subtitle: Text(l10n.sheetSaveToFileSubtitle),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _shareText(text, mode: 'saveFile');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Shows a bottom sheet letting the user pick between copying the
  /// translation as plain text (Markdown stripped) or as raw Markdown.
  ///
  /// Triggered by long-pressing the copy button. The single tap path still
  /// copies plain text (the safer default).
  Future<void> _showCopyOptions(String text) async {
    final l10n = await _overlayL10n();
    if (!mounted) return;
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
                l10n.copyOptionsTitle,
                style: Theme.of(sheetCtx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: Text(l10n.copyAsPlain),
              subtitle: Text(l10n.sheetPlainSubtitle),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _copyText(text, mode: 'plain');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: Text(l10n.copyAsMarkdown),
              subtitle: Text(l10n.sheetCopyMarkdownSubtitle),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _copyText(text, mode: 'markdown');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showOverlaySnackBar(String message) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _surfaceContainerColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(color: _onSurfaceColor, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && entry.mounted) {
        entry.remove();
      }
    });
  }

  Future<String?> _performTranslation(
    String text,
    String targetLanguage,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final templateId = prefs.getString(_kSelectedOverlayTemplatePref);

    if (templateId == null) {
      return 'Error: No overlay template selected. Please open app Settings to configure.';
    }

    final template = await loadTemplate(prefs, templateId);
    if (template == null) {
      return 'Error: Overlay template not found.';
    }

    if (!template.supportsText) {
      return 'Error: Selected template does not support text translation.';
    }

    // Fixed-language templates bake the target language into the prompt
    // body and have no `{{target_language}}` placeholder — the overlay
    // always needs a user-chosen target language, so reject these with the
    // same message the IPC overlay handlers use. The guard also means
    // copy/share buttons below can never export fixed-language output.
    final fixedLanguageError = overlayTemplateGuardError(template);
    if (fixedLanguageError != null) {
      return fixedLanguageError;
    }

    final profile = await loadProfile(prefs, template.profileId);
    if (profile == null) {
      return 'Error: Profile not found for template.';
    }

    final apiKeyValue = await resolveApiKey(prefs, profile);
    if (apiKeyValue == null) {
      return 'Error: No API key configured for profile "${profile.name}".';
    }

    final provider = ProviderFactory.create(
      profile: profile,
      apiKeyValue: apiKeyValue,
    );

    final request = buildTemplateRequest(
      inputText: text,
      targetLanguage: _selectedLanguageName,
      wordCount: text.split(RegExp(r'\s+')).length,
      template: template,
      profile: profile,
    );

    final result = await _runOverlayTranslation(
      provider: provider,
      request: request,
    );
    if (result == null) return null; // cancelled

    _historyService.save(
      inputText: text,
      outputText: result,
      targetLanguage: _selectedLanguageName,
      inputType: 'text',
      modelUsed: profile.model,
      wordCount: text.split(RegExp(r'\s+')).length,
    );

    return result;
  }

  Future<String?> _performScreenshotTranslation(String targetLanguage) async {
    final prefs = await SharedPreferences.getInstance();
    final templateId = prefs.getString(_kSelectedOverlayTemplatePref);

    if (templateId == null) {
      return 'Error: No overlay template selected. Please open app Settings to configure.';
    }

    final template = await loadTemplate(prefs, templateId);
    if (template == null) {
      return 'Error: Overlay template not found.';
    }

    if (!template.supportsImage) {
      return 'Error: Selected template does not support image translation.';
    }

    // Same fixed-output-language guard as the text path and the IPC overlay
    // handlers: the overlay always carries a user-chosen target language,
    // so a template that bakes one into its prompt cannot be driven here.
    final fixedLanguageError = overlayTemplateGuardError(template);
    if (fixedLanguageError != null) {
      return fixedLanguageError;
    }

    if (kDebugMode) {
      debugPrint('[Overlay] Requesting screenshot via service...');
    }
    Uint8List? imageBytes;

    const screenshotChannel = MethodChannel('dev.flutter.org/screenshot');

    try {
      final result = await screenshotChannel
          .invokeMethod<Map<dynamic, dynamic>>('captureScreen');

      if (result == null) {
        return 'Screenshot failed: No result returned.';
      }

      final bytes = result['bytes'];
      if (bytes is Uint8List) {
        imageBytes = bytes;
      } else if (bytes is List) {
        imageBytes = Uint8List.fromList(bytes.cast<int>());
      }

      if (kDebugMode) {
        debugPrint(
          '[Overlay] Screenshot taken: ${imageBytes?.length ?? 0} bytes',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Overlay] Screenshot failed: $e\n$st');
      }
      return 'Screenshot failed: $e';
    }

    if (imageBytes == null || imageBytes.isEmpty) {
      return 'Screenshot failed or was cancelled.';
    }

    final profile = await loadProfile(prefs, template.profileId);
    if (profile == null) {
      return 'Error: Profile not found for template.';
    }

    final apiKeyValue = await resolveApiKey(prefs, profile);
    if (apiKeyValue == null) {
      return 'Error: No API key configured for profile "${profile.name}".';
    }

    final provider = ProviderFactory.create(
      profile: profile,
      apiKeyValue: apiKeyValue,
    );

    final request = buildTemplateRequest(
      inputText: 'Translate text from image',
      targetLanguage: _selectedLanguageName,
      imageBase64: base64Encode(imageBytes),
      imageMimeType: 'image/png',
      wordCount: 0,
      model: profile.visionModel ?? profile.model,
      template: template,
      profile: profile,
    );

    final result = await _runOverlayTranslation(
      provider: provider,
      request: request,
    );
    if (result == null) return null; // cancelled

    _historyService.save(
      inputText: 'Screenshot translation',
      outputText: result,
      targetLanguage: _selectedLanguageName,
      inputType: 'screenshot',
      modelUsed: profile.visionModel ?? profile.model,
      wordCount: 0,
    );

    return result;
  }

  /// Runs [provider]/[request] with an immediate cancel path for the
  /// direct overlay engine.
  ///
  /// Returns the accumulated translation text, or `null` when the user
  /// cancelled (in which case no history entry is written). On cancel the
  /// in-flight HTTP request is aborted via a [CancelToken] and the await
  /// races natural completion against a cancel completer, so the UI
  /// switches back instantly without waiting for the next chunk.
  Future<String?> _runOverlayTranslation({
    required TranslationProvider provider,
    required TranslationRequest request,
  }) async {
    final token = CancelToken();
    final cancelCompleter = Completer<void>();
    _translationCancelToken = token;
    _cancelRaceCompleter = cancelCompleter;

    final buffer = StringBuffer();
    final completer = Completer<void>();
    StreamSubscription<String>? subscription;
    subscription = provider
        .translate(request, cancelToken: token)
        .listen(
          (chunk) {
            if (_isCancelled) {
              subscription?.cancel();
              if (!completer.isCompleted) completer.complete();
              return;
            }
            buffer.write(chunk);
            if (mounted) {
              setState(() {
                _translatedText = buffer.toString();
              });
            }
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          onError: (e) {
            // A race-completer completion means the user cancelled — the
            // abort error arriving afterwards is noise, swallow it.
            if (cancelCompleter.isCompleted) return;
            if (!completer.isCompleted) completer.completeError(e);
          },
          cancelOnError: true,
        );

    try {
      // Race natural completion against the cancel signal so the UI reacts
      // immediately; the HTTP abort happens in parallel via [token].
      await Future.any([completer.future, cancelCompleter.future]);
    } finally {
      subscription.cancel();
      subscription = null;
      _translationCancelToken = null;
      _cancelRaceCompleter = null;
    }

    if (_isCancelled || cancelCompleter.isCompleted) {
      return null;
    }
    final result = buffer.toString();
    if (result.isEmpty) {
      throw const TranslationException('Empty translation result');
    }
    return result;
  }

  void _selectLanguage(String name, String code) {
    setState(() {
      _selectedLanguageName = name;
      _selectedLanguageCode = code;
    });
    _saveSelectedLanguage(name, code);
  }

  static const List<String> _kLanguageNames = [
    'English',
    'Spanish',
    'French',
    'German',
    'Italian',
    'Portuguese',
    'Russian',
    'Chinese',
    'Japanese',
    'Korean',
    'Arabic',
    'Hindi',
    'Turkish',
    'Dutch',
    'Polish',
    'Swedish',
    'Danish',
    'Finnish',
    'Norwegian',
    'Czech',
    'Greek',
    'Hebrew',
    'Thai',
    'Vietnamese',
    'Indonesian',
    'Ukrainian',
    'Romanian',
    'Hungarian',
    'Catalan',
  ];

  @override
  Widget build(BuildContext context) {
    final isFull = _isFullMode;

    final cardContent = FocusScope(
      autofocus: true,
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    maxLines: 4,
                    textDirection: _inputDirection,
                    textAlign: _inputDirection == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                    style: TextStyle(color: _onSurfaceColor, fontSize: 14),
                    selectionControls: MaterialTextSelectionControls(),
                    contextMenuBuilder: (context, editableTextState) {
                      return AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'Paste or enter text...',
                      hintStyle: TextStyle(color: _onSurfaceVariantColor),
                      filled: true,
                      fillColor: _surfaceContainerColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _inputController.text.isEmpty
                          ? IconButton(
                              icon: const Icon(Icons.paste, size: 20),
                              tooltip: 'Paste from clipboard',
                              color: _onSurfaceVariantColor,
                              onPressed: _pasteFromClipboard,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: ElevatedButton.icon(
                          onPressed: !_isLoading
                              ? (_isCancelling ? null : _handleTranslate)
                              : (_isCancelling ? null : _handleCancel),
                          icon: Icon(
                            _isCancelling
                                ? Icons.hourglass_empty
                                : (_isLoading ? Icons.close : Icons.translate),
                            size: 16,
                          ),
                          label: Text(
                            _isCancelling
                                ? 'Cancelling...'
                                : (_isLoading ? 'Cancel' : 'Translate'),
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            backgroundColor: _primaryColor,
                            // Override the foreground so the 'Translate'
                            // label stays legible against the themed
                            // primary color in both light and dark modes.
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading && !_isCancelling
                              ? null
                              : _handleScreenshot,
                          icon: const Icon(Icons.screenshot, size: 16),
                          label: const Text(
                            'Screenshot',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            foregroundColor: _onSurfaceColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: _canClear ? _handleClear : null,
                        icon: const Icon(Icons.cleaning_services, size: 20),
                        tooltip: 'Clear input and output',
                        style: IconButton.styleFrom(
                          backgroundColor: _surfaceContainerColor,
                          foregroundColor: _canClear
                              ? _onSurfaceColor
                              : _onSurfaceVariantColor,
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: _onSurfaceVariantColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(minHeight: 80),
                    decoration: BoxDecoration(
                      color: _surfaceContainerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _translatedText.isNotEmpty
                        ? BiDiMarkdownView(
                            markdownText: _translatedText,
                            selectable: true,
                          )
                        : _isLoading
                        ? const BiDiMarkdownView.loading()
                        : Text(
                            'Translation will appear here',
                            style: TextStyle(
                              color: _onSurfaceVariantColor,
                              fontSize: 14,
                            ),
                          ),
                  ),
                  if (_translatedText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share, size: 20),
                            tooltip: 'Share translation',
                            onPressed: () => _showShareOptions(_translatedText),
                            onLongPress: () => _shareText(_translatedText),
                            color: _onSurfaceVariantColor,
                          ),
                          if (_showCopiedFeedback)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'Copied!',
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.copy, size: 20),
                              tooltip: 'Copy translation',
                              onPressed: () => _copyText(_translatedText),
                              onLongPress: () =>
                                  _showCopyOptions(_translatedText),
                              color: _onSurfaceVariantColor,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
              ? constraints.maxWidth
              : MediaQuery.of(context).size.width;
          final maxH =
              constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : MediaQuery.of(context).size.height;

          if (isFull) {
            return SafeArea(
              child: GestureDetector(
                onTap: _handleOverlayTap,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _surfaceColor),
                  child: cardContent,
                ),
              ),
            );
          }

          final cardWidth = math.max(320.0, math.min(360.0, maxW * 0.9));
          final cardHeight = math.max(440.0, math.min(580.0, maxH * 0.75));
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _handleOutsideTap,
                  child: Container(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: _handleOverlayTap,
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primaryColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: cardContent,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleOverlayTap() async {
    try {
      await _overlayChannel.invokeMethod('focusable', {'enable': true});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Failed to enable focus: $e');
      }
    }
  }

  void _handleOutsideTap() {
    if (kDebugMode) {
      debugPrint('[Overlay] Outside tapped - closing overlay');
    }
    _handleClose();
  }

  Future<void> _showLanguageModal() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _onSurfaceVariantColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Select Language',
                    style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: _onSurfaceColor),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _kLanguageNames.length,
                itemBuilder: (context, index) {
                  final name = _kLanguageNames[index];
                  final isSelected = _selectedLanguageName == name;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? _primaryColor
                          : _onSurfaceVariantColor,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? _primaryColor : _onSurfaceColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      final code = getLanguageCode(selected) ?? 'en';
      _selectLanguage(selected, code);
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.translate, color: _primaryColor, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Translator',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: _onSurfaceColor,
            ),
          ),
        ),
        GestureDetector(
          onTap: _showLanguageModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _surfaceContainerColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedLanguageCode.toUpperCase(),
                  style: TextStyle(
                    color: _onSurfaceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: _onSurfaceColor, size: 16),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(Icons.close, color: _onSurfaceColor, size: 20),
          onPressed: _handleClose,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  // Sweep leftover temp `.md` files from previous sessions. Files newer
  // than the grace period are kept, so a file still being read by a share
  // target is never touched. Non-blocking: startup proceeds immediately.
  unawaited(
    DeferredTempFileCleanup.instance.cleanupStaleFiles().catchError((Object e) {
      if (kDebugMode) {
        debugPrint('Temp file cleanup failed (non-fatal): $e');
      }
    }),
  );

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Failed to initialize SharedPreferences: $e');
    }
  }

  if (prefs != null) {
    try {
      final secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(),
      );
      final repo = SettingsRepository(
        secureStorage: secureStorage,
        prefs: prefs,
      );
      await repo.migrateToProfileSystem();
      await repo.restoreBuiltInItems();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Migration failed (non-fatal): $e');
      }
    }
  }

  if (prefs != null) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    runApp(JusoorApp(container: container));

    // Request POST_NOTIFICATIONS permission on Android 13+ (API 33+)
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        const MethodChannel(
          'dev.flutter.org/overlay_permission',
        ).invokeMethod('requestNotificationPermission');
      });
    }
  } else {
    runApp(const _InitializationErrorApp());
  }

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('PlatformDispatcher error: $error');
    }
    return true;
  };
}

class _InitializationErrorApp extends StatelessWidget {
  const _InitializationErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kSeedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The app could not initialize properly. Please try restarting. '
                  'If the problem persists, try clearing the app data.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
