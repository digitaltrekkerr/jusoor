import 'dart:async';
import 'dart:convert';

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
  streamTranslationSubscription = provider.translate(request).listen(
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
      FlutterOverlayWindow.shareData(jsonEncode({
        'type': 'translation_result',
        'result': 'Error: $e',
        'isStreaming': false,
      }));
      completer.complete();
    },
    cancelOnError: true,
  );

  await completer.future;
}