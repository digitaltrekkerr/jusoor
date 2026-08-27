import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:translation_core/translation_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:history/history.dart';

import 'overlay_utils.dart';
import '../providers/translation_provider.dart';

const String _kSelectedOverlayTemplatePref = 'selected_overlay_template';

const MethodChannel _screenshotChannel = MethodChannel(
  'dev.flutter.org/screenshot',
);

const int _kOverlayHeightWrapContent = -3;

StreamSubscription<dynamic>? _overlaySubscription;

@pragma("vm:entry-point")
Future<void> showTranslatorOverlay() async {
  try {
    final bool hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    if (kDebugMode) {
      debugPrint('[Overlay] Permission granted: $hasPermission');
    }
    if (!hasPermission) {
      await FlutterOverlayWindow.requestPermission();
      return;
    }

    if (kDebugMode) {
      debugPrint('[Overlay] Showing overlay...');
    }

    await FlutterOverlayWindow.showOverlay(
      height:
          _kOverlayHeightWrapContent, // -3 indicates wrap-content behavior in the overlay API
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      overlayTitle: "",
      overlayContent: "",
      enableDrag: false,
      positionGravity: PositionGravity.none,
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilitySecret,
    );

    try {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
      if (kDebugMode) {
        debugPrint('[Overlay] Updated overlay flags');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Overlay] Failed to update overlay flags: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    await FlutterOverlayWindow.shareData(jsonEncode({'type': 'clear_state'}));

    if (kDebugMode) {
      debugPrint('[Overlay] showOverlay completed');
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Overlay] Error in showTranslatorOverlay: $e\n$st');
    }
  }
}

@pragma("vm:entry-point")
void setupOverlayIPC() {
  _overlaySubscription?.cancel();
  _overlaySubscription = FlutterOverlayWindow.overlayListener.listen((
    data,
  ) async {
    if (data == null) return;

    Map<String, dynamic> map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
    } else if (data is String) {
      try {
        map = jsonDecode(data);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to decode IPC data: $e');
        }
        return;
      }
    } else {
      return;
    }

    if (kDebugMode) {
      debugPrint('[OverlayIPC] Received: ${map['type']}');
    }

    switch (map['type']) {
      case 'translate_text':
        await _handleTranslateText(map);
        break;

      case 'take_screenshot':
        await _handleScreenshot(map);
        break;

      case 'cancel_translation':
        streamTranslationCancellationRequested = true;
        streamTranslationCancelToken?.cancel();
        streamTranslationSubscription?.cancel();
        streamTranslationSubscription = null;
        FlutterOverlayWindow.shareData(
          jsonEncode({
            'type': 'translation_result',
            'result': '',
            'isStreaming': false,
            'cancelled': true,
          }),
        );
        _saveCancelledTranslation(
          map['text']?.toString(),
          map['target']?.toString(),
        );
        break;
    }
  });
}

Future<void> _handleTranslateText(Map<String, dynamic> map) async {
  final text = map['text']?.toString() ?? '';
  final targetLanguage = map['target']?.toString() ?? 'en';

  if (text.isEmpty) return;

  final prefs = await SharedPreferences.getInstance();
  final templateId = prefs.getString(_kSelectedOverlayTemplatePref);

  if (templateId == null) {
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result':
            'Error: No overlay template selected. Please open app Settings to configure.',
      }),
    );
    return;
  }

  final template = await loadTemplate(prefs, templateId);
  if (template == null) {
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result':
            'Error: Overlay template not found. Please open app Settings to configure.',
      }),
    );
    return;
  }

  if (!template.supportsText) {
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result': 'Error: Selected template does not support text translation.',
      }),
    );
    return;
  }

  // Fixed-language templates bake the target language into the prompt
  // body and have no `{{target_language}}` placeholder. The overlay
  // always needs a user-chosen target language carried by the `target`
  // IPC field, so it cannot drive these templates — reject early with
  // a clear actionable message.
  if (template.outputLanguageFixed) {
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result':
            'Error: Selected template has a fixed output language and is '
            'not compatible with floating overlay translation. Please '
            'open app Settings to pick a different overlay template.',
      }),
    );
    return;
  }

  final profile = await loadProfile(prefs, template.profileId);
  if (profile == null) {
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result': 'Error: Profile not found for template.',
      }),
    );
    return;
  }

  final apiKeyValue = await resolveApiKey(prefs, profile);
  if (apiKeyValue == null) {
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result': 'Error: No API key configured for profile "${profile.name}".',
      }),
    );
    return;
  }

  try {
    final provider = ProviderFactory.create(
      profile: profile,
      apiKeyValue: apiKeyValue,
    );

    final request = buildTemplateRequest(
      inputText: text,
      targetLanguage: targetLanguage,
      wordCount: text.split(RegExp(r'\s+')).length,
      template: template,
      profile: profile,
    );

    final buffer = StringBuffer();
    final completer = Completer<void>();

    await streamTranslation(
      provider: provider,
      request: request,
      buffer: buffer,
      completer: completer,
      onChunk: (result) {
        FlutterOverlayWindow.shareData(
          jsonEncode({
            'type': 'translation_result',
            'result': result,
            'isStreaming': true,
          }),
        );
      },
      onDone: () {
        FlutterOverlayWindow.shareData(
          jsonEncode({
            'type': 'translation_result',
            'result': buffer.toString(),
            'isStreaming': false,
          }),
        );
      },
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[OverlayIPC] Translation error: $e');
    }
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result': 'Error: $e',
        'isStreaming': false,
      }),
    );
  }
}

Future<void> _handleScreenshot(Map<String, dynamic> map) async {
  final targetLanguage = map['target']?.toString() ?? 'en';

  final prefs = await SharedPreferences.getInstance();
  final templateId = prefs.getString(_kSelectedOverlayTemplatePref);

  if (templateId == null) {
    await _sendError(
      'Error: No overlay template selected. Please open app Settings to configure.',
    );
    return;
  }

  final template = await loadTemplate(prefs, templateId);
  if (template == null) {
    await _sendError('Error: Overlay template not found.');
    return;
  }

  if (!template.supportsImage) {
    await _sendError(
      'Error: Selected template does not support image translation.',
    );
    return;
  }

  // Fixed-language templates bake the target language into the prompt
  // body — the overlay always needs a user-chosen target language via
  // the `target` IPC field, so refuse to drive these from the overlay.
  if (template.outputLanguageFixed) {
    await _sendError(
      'Error: Selected template has a fixed output language and is '
      'not compatible with floating overlay translation. Please open '
      'app Settings to pick a different overlay template.',
    );
    return;
  }

  if (kDebugMode) {
    debugPrint('[OverlayIPC] Requesting screenshot capture...');
  }

  Uint8List? imageBytes;

  try {
    final result = await _screenshotChannel.invokeMethod<Map<dynamic, dynamic>>(
      'captureScreen',
    );

    if (result == null) {
      await _sendError('Screenshot failed: No result returned.');
      return;
    }

    final bytes = result['bytes'];
    if (bytes is Uint8List) {
      imageBytes = bytes;
    } else if (bytes is List) {
      imageBytes = Uint8List.fromList(bytes.cast<int>());
    }

    if (kDebugMode) {
      debugPrint(
        '[OverlayIPC] Screenshot captured: ${imageBytes?.length ?? 0} bytes',
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[OverlayIPC] Screenshot error: $e');
    }
    await _sendError('Screenshot failed: $e');
    return;
  }

  if (imageBytes == null || imageBytes.isEmpty) {
    await _sendError('Screenshot failed or was cancelled.');
    return;
  }

  final profile = await loadProfile(prefs, template.profileId);
  if (profile == null) {
    await _sendError('Error: Profile not found for template.');
    return;
  }

  final apiKeyValue = await resolveApiKey(prefs, profile);
  if (apiKeyValue == null) {
    await _sendError(
      'Error: No API key configured for profile "${profile.name}".',
    );
    return;
  }

  try {
    final provider = ProviderFactory.create(
      profile: profile,
      apiKeyValue: apiKeyValue,
    );

    final request = buildTemplateRequest(
      inputText: 'Translate text from image',
      targetLanguage: targetLanguage,
      imageBase64: base64Encode(imageBytes),
      imageMimeType: 'image/png',
      wordCount: 0,
      model: profile.visionModel ?? profile.model,
      template: template,
      profile: profile,
    );

    final buffer = StringBuffer();
    final completer = Completer<void>();

    await streamTranslation(
      provider: provider,
      request: request,
      buffer: buffer,
      completer: completer,
      onChunk: (result) {
        FlutterOverlayWindow.shareData(
          jsonEncode({
            'type': 'translation_result',
            'result': result,
            'isStreaming': true,
          }),
        );
      },
      onDone: () {
        FlutterOverlayWindow.shareData(
          jsonEncode({
            'type': 'translation_result',
            'result': buffer.toString(),
            'isStreaming': false,
          }),
        );
      },
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[OverlayIPC] Image translation error: $e');
    }
    await FlutterOverlayWindow.shareData(
      jsonEncode({
        'type': 'translation_result',
        'result': 'Error: $e',
        'isStreaming': false,
      }),
    );
  }
}

Future<void> _sendError(String message) async {
  await FlutterOverlayWindow.shareData(
    jsonEncode({
      'type': 'translation_result',
      'result': message,
      'isStreaming': false,
    }),
  );
}

@pragma("vm:entry-point")
final HistoryService _historyService = HistoryService();

Future<void> _saveCancelledTranslation(
  String? text,
  String? targetLanguage,
) async {
  if (text == null || text.isEmpty) return;
  try {
    await _historyService.save(
      inputText: text,
      outputText: '[Cancelled]',
      targetLanguage: targetLanguage ?? 'en',
      inputType: 'text',
      modelUsed: 'unknown',
      wordCount: text.split(RegExp(r'\s+')).length,
    );
    if (kDebugMode) {
      debugPrint('[OverlayIPC] Saved cancelled translation to history');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[OverlayIPC] Failed to save cancelled translation: $e');
    }
  }
}
