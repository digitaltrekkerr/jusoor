import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:history/history.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_core/translation_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'overlay/overlay_utils.dart';
import 'providers/settings_provider.dart';
import 'services/settings_repository.dart';
import 'widgets/bidi_markdown_view.dart';
import 'widgets/language_dropdown.dart';

const Color _kSeedColor = Color(0xFF4F46E5);
const String _kSelectedOverlayTemplatePref = 'selected_overlay_template';
const String _kDefaultTargetLanguageKey = 'default_target_language';
const String _kOverlaySelectedLanguageKey = 'overlay_selected_language';

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[OverlayMain] WidgetsFlutterBinding initialized');
  
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

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  static const _overlayChannel = MethodChannel('x-slayer/overlay');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
      ],
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            try {
              await _overlayChannel.invokeMethod('close');
            } catch (e) {
              debugPrint('[Overlay] Close error: $e');
            }
          }
        },
        child: const _TranslatorOverlayContent(),
      ),
    );
  }
}

class _TranslatorOverlayContent extends StatefulWidget {
  const _TranslatorOverlayContent();

  @override
  State<_TranslatorOverlayContent> createState() => _TranslatorOverlayContentState();
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

  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _surfaceColor = Color(0xFF1E1E2E);
  static const Color _surfaceContainerColor = Color(0xFF2D2D3D);
  static const Color _onSurfaceColor = Colors.white;
  static const Color _onSurfaceVariantColor = Color(0xFFB0B0C0);

  StreamSubscription<dynamic>? _overlaySubscription;
  bool _isCancelled = false;
  final HistoryService _historyService = HistoryService();
  bool _isFullMode = false;
  bool _needsInitialDetection = true;

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
        debugPrint('[Overlay] Initial focus enable error: $e');
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
        debugPrint('[Overlay] Focus update error: $e');
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
      
      debugPrint('[OverlayWidget] Received: ${map['type']}');
      
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
            _translatedText = wasCancelled ? '' : (map['result']?.toString() ?? 'Error');
            _isLoading = false;
            _isCancelling = false;
          });
        }
      }
    });
    
  }

  Future<void> _loadDefaultLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    
    String languageCode = prefs.getString(_kOverlaySelectedLanguageKey) ?? 
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
      setState(() { _inputDirection = newDir; });
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
        debugPrint(
          '[Overlay-Paste] Native clipboard: $source, ${text?.length ?? 0} chars',
        );
        if (isStale && text != null && text.isNotEmpty) {
          _showOverlaySnackBar(
            'Clipboard: ${text.length} chars (cached)',
          );
        }
      }
    } on TimeoutException {
      debugPrint('[Overlay-Paste] Native clipboard timed out');
    } catch (e, st) {
      debugPrint('[Overlay-Paste] Native clipboard error: $e\n$st');
    }

    if (text != null && text.isNotEmpty) {
      _insertAtCursor(text);
      debugPrint('[Overlay-Paste] Pasted via $source: ${text.length} chars');
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
      debugPrint('[Overlay] Close error: $e');
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
          _translatedText = result;
        });
      }
    } catch (e) {
      if (mounted) {
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

    try {
      await FlutterOverlayWindow.shareData(jsonEncode({
        'type': 'cancel_translation',
      }));
    } catch (e) {
      debugPrint('[Overlay] Cancel signal error: $e');
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
          _translatedText = result;
        });
      }
    } catch (e) {
      if (mounted) {
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

  void _copyText(String text) {
    _overlayChannel
        .invokeMethod('writeClipboard', {'text': text})
        .then((_) => debugPrint('[Overlay-Paste] Copied: ${text.length} chars'))
        .catchError((e) => debugPrint('[Overlay-Paste] Copy error: $e'));
    setState(() { _showCopiedFeedback = true; });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() { _showCopiedFeedback = false; });
    });
  }

  Future<void> _shareText(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      debugPrint('[Overlay] Share error: $e');
    }
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
                style: const TextStyle(color: _onSurfaceColor, fontSize: 14),
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

  Future<String> _performTranslation(String text, String targetLanguage) async {
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

    final request = TranslationRequest(
      inputText: text,
      targetLanguage: _selectedLanguageName,
      model: profile.model,
      systemPrompt: template.systemPrompt,
      profileId: profile.id,
      wordCount: text.split(RegExp(r'\s+')).length,
    );

    final buffer = StringBuffer();
    final completer = Completer<void>();
    StreamSubscription<String>? subscription;
    subscription = provider.translate(request).listen(
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
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    await completer.future;
    subscription.cancel();
    subscription = null;

    if (_isCancelled) {
      return 'Translation cancelled';
    }

    final result = buffer.toString();
    if (result.isNotEmpty) {
      _historyService.save(
        inputText: text,
        outputText: result,
        targetLanguage: _selectedLanguageName,
        inputType: 'text',
        modelUsed: profile.model,
        wordCount: text.split(RegExp(r'\s+')).length,
      );
    }

    return result;
  }

  Future<String> _performScreenshotTranslation(String targetLanguage) async {
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

    debugPrint('[Overlay] Requesting screenshot via service...');
    Uint8List? imageBytes;
    
    const screenshotChannel = MethodChannel('dev.flutter.org/screenshot');
    
    try {
      final result = await screenshotChannel.invokeMethod<Map<dynamic, dynamic>>('captureScreen');
      
      if (result == null) {
        return 'Screenshot failed: No result returned.';
      }
      
      final bytes = result['bytes'];
      if (bytes is Uint8List) {
        imageBytes = bytes;
      } else if (bytes is List) {
        imageBytes = Uint8List.fromList(bytes.cast<int>());
      }
      
      debugPrint('[Overlay] Screenshot taken: ${imageBytes?.length ?? 0} bytes');
    } catch (e, st) {
      debugPrint('[Overlay] Screenshot failed: $e\n$st');
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

    final request = TranslationRequest(
      inputText: 'Translate text from image',
      targetLanguage: _selectedLanguageName,
      imageBase64: base64Encode(imageBytes),
      imageMimeType: 'image/png',
      model: profile.visionModel ?? profile.model,
      systemPrompt: template.systemPrompt,
      profileId: profile.id,
      wordCount: 0,
    );

    final buffer = StringBuffer();
    final completer = Completer<void>();
    StreamSubscription<String>? subscription;
    subscription = provider.translate(request).listen(
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
        if (!completer.isCompleted) completer.completeError(e);
      },
      cancelOnError: true,
    );

    await completer.future;
    subscription.cancel();
    subscription = null;

    if (_isCancelled) {
      return 'Translation cancelled';
    }

    final result = buffer.toString();
    if (result.isNotEmpty) {
      _historyService.save(
        inputText: 'Screenshot translation',
        outputText: result,
        targetLanguage: _selectedLanguageName,
        inputType: 'screenshot',
        modelUsed: profile.visionModel ?? profile.model,
        wordCount: 0,
      );
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
    'English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese',
    'Russian', 'Chinese', 'Japanese', 'Korean', 'Arabic', 'Hindi',
    'Turkish', 'Dutch', 'Polish', 'Swedish', 'Danish', 'Finnish',
    'Norwegian', 'Czech', 'Greek', 'Hebrew', 'Thai', 'Vietnamese',
    'Indonesian', 'Ukrainian', 'Romanian', 'Hungarian', 'Catalan',
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
                    style: const TextStyle(color: _onSurfaceColor, fontSize: 14),
                    selectionControls: MaterialTextSelectionControls(),
                    contextMenuBuilder: (context, editableTextState) {
                      return AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      );
                    },
                    decoration: InputDecoration(
                      hintText: 'Paste or enter text...',
                      hintStyle: const TextStyle(color: _onSurfaceVariantColor),
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
                            _isCancelling ? Icons.hourglass_empty : 
                              (_isLoading ? Icons.close : Icons.translate), 
                            size: 16
                          ),
                          label: Text(
                            _isCancelling ? 'Cancelling...' : 
                              (_isLoading ? 'Cancel' : 'Translate'),
                            style: const TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            backgroundColor: _primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 4,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading && !_isCancelling ? null : _handleScreenshot,
                          icon: const Icon(Icons.screenshot, size: 16),
                          label: const Text('Screenshot', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                          foregroundColor: _canClear ? _onSurfaceColor : _onSurfaceVariantColor,
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: _onSurfaceVariantColor.withValues(alpha: 0.3)),
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
                        ? BiDiMarkdownView(markdownText: _translatedText, selectable: true)
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
                            onPressed: () async { await _shareText(_translatedText); },
                            color: _onSurfaceVariantColor,
                          ),
                          if (_showCopiedFeedback)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
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
          final maxH = constraints.maxHeight.isFinite && constraints.maxHeight > 0
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
                  decoration: BoxDecoration(
                    color: _surfaceColor,
                  ),
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
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
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
      debugPrint('[Overlay] Failed to enable focus: $e');
    }
  }

  void _handleOutsideTap() {
    debugPrint('[Overlay] Outside tapped - closing overlay');
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
                  const Text(
                    'Select Language',
                    style: TextStyle(
                      color: _onSurfaceColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: _onSurfaceColor),
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
                      color: isSelected ? _primaryColor : _onSurfaceVariantColor,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: isSelected ? _primaryColor : _onSurfaceColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        const Icon(Icons.translate, color: _primaryColor, size: 24),
        const SizedBox(width: 8),
        const Expanded(
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
                  style: const TextStyle(
                    color: _onSurfaceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  color: _onSurfaceColor,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.close, color: _onSurfaceColor, size: 20),
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
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('Failed to initialize SharedPreferences: $e');
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
      debugPrint('Migration failed (non-fatal): $e');
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
      const MethodChannel('dev.flutter.org/overlay_permission')
          .invokeMethod('requestNotificationPermission');
    });
  }
  } else {
    runApp(const _InitializationErrorApp());
  }

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    debugPrint('PlatformDispatcher error: $error');
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