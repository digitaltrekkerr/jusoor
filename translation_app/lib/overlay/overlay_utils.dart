import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_core/translation_core.dart';

const String _kTemplatesKey = 'prompt_templates';
const String _kProfilesKey = 'provider_profiles';

final secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());

StreamSubscription<String>? streamTranslationSubscription;
bool streamTranslationCancellationRequested = false;

/// Aborts the in-flight overlay translation HTTP request. Created fresh per
/// [streamTranslation] call; the `cancel_translation` IPC handler cancels it
/// so the provider throws [TranslationCancelledException] instead of waiting
/// for the server.
CancelToken? streamTranslationCancelToken;

Future<PromptTemplate?> loadTemplate(SharedPreferences prefs, String templateId) async {
  final templatesJson = prefs.getString(_kTemplatesKey);
  if (templatesJson == null) return null;

  try {
    final List<dynamic> templates = jsonDecode(templatesJson);
    for (final t in templates) {
      if (t['id'] == templateId) {
        return PromptTemplate.fromJson(Map<String, dynamic>.from(t));
      }
    }
  } catch (e) {
    debugPrint('[OverlayUtils] Error loading template: $e');
  }
  return null;
}

Future<ProviderProfile?> loadProfile(SharedPreferences prefs, String profileId) async {
  final profilesJson = prefs.getString(_kProfilesKey);
  if (profilesJson == null) return null;

  try {
    final List<dynamic> profiles = jsonDecode(profilesJson);
    for (final p in profiles) {
      if (p['id'] == profileId) {
        return ProviderProfile.fromJson(Map<String, dynamic>.from(p));
      }
    }
  } catch (e) {
    debugPrint('[OverlayUtils] Error loading profile: $e');
  }
  return null;
}

Future<String?> resolveApiKey(SharedPreferences prefs, ProviderProfile profile) async {
  if (profile.apiKeyId != null) {
    final value = await secureStorage.read(key: 'api_key_${profile.apiKeyId}');
    if (value != null && value.isNotEmpty) return value;
  }

  if (profile.fallbackApiKeyId != null) {
    final value = await secureStorage.read(key: 'api_key_${profile.fallbackApiKeyId}');
    if (value != null && value.isNotEmpty) return value;
  }

  return null;
}

Future<void> streamTranslation({
  required TranslationProvider provider,
  required TranslationRequest request,
  required StringBuffer buffer,
  required Completer<void> completer,
  required void Function(String) onChunk,
  required void Function() onDone,
}) async {
  streamTranslationCancellationRequested = false;
  streamTranslationCancelToken = CancelToken();
  streamTranslationSubscription = provider
      .translate(request, cancelToken: streamTranslationCancelToken)
      .listen(
        (chunk) {
          buffer.write(chunk);
          onChunk(buffer.toString());
        },
        onDone: () {
          streamTranslationSubscription = null;
          if (!streamTranslationCancellationRequested) {
            onDone();
          }
          completer.complete();
        },
        onError: (e) {
          streamTranslationSubscription = null;
          // The user cancelled — the overlay already received the empty
          // `cancelled: true` payload from the cancel handler; do not
          // surface an error on top of it.
          if (!streamTranslationCancellationRequested &&
              !_isCancellation(e)) {
            FlutterOverlayWindow.shareData(jsonEncode({
              'type': 'translation_result',
              'result': 'Error: $e',
              'isStreaming': false,
            }));
          }
          completer.complete();
        },
        cancelOnError: true,
      );

  await completer.future;
}

/// Returns `true` when [e] represents a user-initiated cancellation rather
/// than a genuine failure.
bool _isCancellation(Object e) {
  if (e is TranslationCancelledException) return true;
  if (e is DioException && CancelToken.isCancel(e)) return true;
  return false;
}