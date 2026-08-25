import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:history/history.dart';
import 'package:translation_core/translation_core.dart';

import 'settings_provider.dart';

// ── Translation State ────────────────────────────────────────────────

/// Base class for translation UI states.
sealed class TranslationState {
  const TranslationState();
}

/// No translation has been requested yet.
class TranslationIdle extends TranslationState {
  const TranslationIdle();
}

/// A translation request has been sent and we are waiting for the first chunk.
class TranslationLoading extends TranslationState {
  const TranslationLoading();
}

/// Streaming chunks are arriving; [partial] contains the text so far.
class TranslationStreaming extends TranslationState {
  /// The partial translation text accumulated so far.
  final String partial;

  /// Creates a [TranslationStreaming] state.
  const TranslationStreaming(this.partial);
}

/// Translation completed successfully.
class TranslationDone extends TranslationState {
  /// The full translated text.
  final String fullText;

  /// The model identifier that was used.
  final String modelUsed;

  /// Wall-clock duration of the translation in milliseconds.
  final int durationMs;

  /// Creates a [TranslationDone] state.
  const TranslationDone(this.fullText, this.modelUsed, this.durationMs);
}

/// Translation failed with [message].
class TranslationError extends TranslationState {
  /// Human-readable error description.
  final String message;

  /// Creates a [TranslationError] state.
  const TranslationError(this.message);
}

// ── Translation Notifier ─────────────────────────────────────────────

/// Provides the [TranslationNotifier] instance.
final translationProvider =
    NotifierProvider<TranslationNotifier, TranslationState>(
      TranslationNotifier.new,
    );

/// Manages translation state: idle → loading → streaming → done (or error).
///
/// Uses the Profile & Template system to resolve the provider, model, and
/// system prompt. On successful completion, the result is auto-saved to
/// [HistoryService]. If translation fails and a fallback profile is
/// configured, a single retry is attempted.
class TranslationNotifier extends Notifier<TranslationState> {
  bool _isCancelled = false;

  @override
  TranslationState build() => const TranslationIdle();

  /// Sends a translation request and streams the response.
  ///
  /// Resolves the template (text or image), profile, and API key from the
  /// new Profile & Template system, then streams the translation through the
  /// state machine: [TranslationLoading] → [TranslationStreaming] →
  /// [TranslationDone] (or [TranslationError]).
  ///
  /// If the primary translation fails and a fallback profile is selected,
  /// a single retry is attempted using the fallback profile.
  Future<void> translate(TranslationRequest request) async {
    _isCancelled = false;
    state = const TranslationLoading();

    final stopwatch = Stopwatch()..start();

    // Capture the resolved system prompt before the try block so it is
    // available in catch clauses for fallback.  It gets overwritten once
    // the template is resolved inside try.
    var resolvedSystemPrompt = request.systemPrompt;

    try {
      // ── Resolve template ────────────────────────────────────────────
      final isImage = request.imageBase64 != null;
      final templateId = isImage
          ? ref.read(selectedImageTemplateProvider)
          : ref.read(selectedTextTemplateProvider);

      if (templateId == null) {
        throw TranslationException(
          'No ${isImage ? "image" : "text"} template selected. '
          'Please select a template in settings.',
        );
      }

      final templates = ref.read(templatesProvider);
      final template = templates.where((t) => t.id == templateId).firstOrNull;
      if (template == null) {
        throw TranslationException(
          'Selected template not found. Please choose a valid template.',
        );
      }

      // Capture the template's system prompt so the fallback uses it even
      // if the user changes templates mid-translation.
      resolvedSystemPrompt = template.systemPrompt;

      // ── Resolve profile ─────────────────────────────────────────────
      final profiles = ref.read(profilesProvider);
      final profile = profiles
          .where((p) => p.id == template.profileId)
          .firstOrNull;
      if (profile == null) {
        throw TranslationException(
          'Profile not found for template "${template.name}". '
          'Please check your template configuration.',
        );
      }

      // ── Resolve API key ─────────────────────────────────────────────
      final apiKeyValue = await _resolveApiKey(profile);
      if (apiKeyValue == null) {
        throw TranslationException(
          'No API key configured for profile "${profile.name}". '
          'Please add an API key in settings.',
        );
      }

      // ── Create provider and build request ────────────────────────────
      final provider = ProviderFactory.create(
        profile: profile,
        apiKeyValue: apiKeyValue,
      );

      final effectiveRequest = TranslationRequest(
        inputText: request.inputText,
        targetLanguage: request.targetLanguage,
        imageBase64: request.imageBase64,
        imageMimeType: request.imageMimeType,
        wordCount: request.wordCount,
        model: profile.model,
        systemPrompt: resolvedSystemPrompt,
        profileId: profile.id,
        substituteTargetLanguage: template.substituteTargetLanguage,
      );

      // ── Stream translation ──────────────────────────────────────────
      await _streamTranslation(
        provider: provider,
        request: effectiveRequest,
        stopwatch: stopwatch,
      );
    } on TranslationException catch (e) {
      // ── Attempt fallback if configured ───────────────────────────────
      final retried = await _tryFallback(
        request: request,
        systemPrompt: resolvedSystemPrompt,
        originalError: e.message,
        stopwatch: stopwatch,
      );
      if (!retried) {
        state = TranslationError(e.message);
      }
    } on ResponsePathException catch (e) {
      final retried = await _tryFallback(
        request: request,
        systemPrompt: resolvedSystemPrompt,
        originalError: 'Response path error: ${e.message}',
        stopwatch: stopwatch,
      );
      if (!retried) {
        state = TranslationError('Response path error: ${e.message}');
      }
    } catch (e) {
      final retried = await _tryFallback(
        request: request,
        systemPrompt: resolvedSystemPrompt,
        originalError: 'Unexpected error: $e',
        stopwatch: stopwatch,
      );
      if (!retried) {
        state = TranslationError('Unexpected error: $e');
      }
    }
  }

  /// Resets the translation state back to idle.
  void reset() {
    state = const TranslationIdle();
  }

  /// Cancels the in-progress translation if any.
  void cancel() {
    _isCancelled = true;
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Resolves the API key value for [profile], trying the fallback key if
  /// the primary key is missing.
  ///
  /// Returns `null` if neither the primary nor the fallback key is available.
  Future<String?> _resolveApiKey(ProviderProfile profile) async {
    final apiKeysNotifier = ref.read(apiKeysProvider.notifier);

    if (profile.apiKeyId != null) {
      final value = await apiKeysNotifier.getApiKeyValue(profile.apiKeyId!);
      if (value != null && value.isNotEmpty) return value;
    }

    // Try fallback API key.
    if (profile.fallbackApiKeyId != null) {
      final value = await apiKeysNotifier.getApiKeyValue(
        profile.fallbackApiKeyId!,
      );
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  /// Streams a translation and updates state through loading → streaming →
  /// done. Saves to history on success.
  ///
  /// Incoming chunks are buffered and flushed to the UI at most once every
  /// [_streamFlushInterval]. Rebuilding the whole markdown output on every
  /// token is O(n²) over the duration of a long translation, so coalescing
  /// the updates keeps the UI responsive without visible lag.
  static const Duration _streamFlushInterval = Duration(milliseconds: 100);

  Future<void> _streamTranslation({
    required TranslationProvider provider,
    required TranslationRequest request,
    required Stopwatch stopwatch,
  }) async {
    final buffer = StringBuffer();
    Timer? flushTimer;
    var emittedFirstChunk = false;

    void cancelFlushTimer() {
      flushTimer?.cancel();
      flushTimer = null;
    }

    void scheduleFlush() {
      if (flushTimer != null) return;
      flushTimer = Timer(_streamFlushInterval, () {
        flushTimer = null;
        if (_isCancelled) return;
        state = TranslationStreaming(buffer.toString());
      });
    }

    await for (final chunk in provider.translate(request)) {
      if (_isCancelled) {
        cancelFlushTimer();
        state = const TranslationIdle();
        return;
      }
      buffer.write(chunk);
      // Publish the first chunk immediately so the spinner switches to
      // streaming output right away; subsequent chunks are coalesced.
      if (!emittedFirstChunk) {
        emittedFirstChunk = true;
        state = TranslationStreaming(buffer.toString());
      } else {
        scheduleFlush();
      }
    }

    cancelFlushTimer();
    if (_isCancelled) {
      state = const TranslationIdle();
      return;
    }

    stopwatch.stop();
    final fullText = buffer.toString();
    final modelUsed = request.model;

    if (fullText.isEmpty) {
      state = TranslationError(
        'Translation returned an empty result. '
        'This may indicate a response parsing error or an unsupported '
        'API response format.',
      );
      return;
    }

    state = TranslationDone(fullText, modelUsed, stopwatch.elapsedMilliseconds);

    _saveToHistory(
      request: request,
      fullText: fullText,
      modelUsed: modelUsed,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Attempts a single retry using the fallback profile if one is selected.
  ///
  /// Returns `true` if a retry was attempted (whether it succeeded or not).
  /// Returns `false` if no fallback profile is configured, meaning the caller
  /// should report the [originalError].
  Future<bool> _tryFallback({
    required TranslationRequest request,
    required String systemPrompt,
    required String originalError,
    required Stopwatch stopwatch,
  }) async {
    final fallbackProfileId = ref.read(selectedFallbackProfileProvider);
    if (fallbackProfileId == null) return false;

    final profiles = ref.read(profilesProvider);
    final fallbackProfile = profiles
        .where((p) => p.id == fallbackProfileId)
        .firstOrNull;
    if (fallbackProfile == null) return false;

    final apiKeyValue = await _resolveApiKey(fallbackProfile);
    if (apiKeyValue == null) return false;

    // Reset state for retry.
    state = const TranslationLoading();
    _isCancelled = false;

    try {
      final provider = ProviderFactory.create(
        profile: fallbackProfile,
        apiKeyValue: apiKeyValue,
      );

      final fallbackRequest = TranslationRequest(
        inputText: request.inputText,
        targetLanguage: request.targetLanguage,
        imageBase64: request.imageBase64,
        imageMimeType: request.imageMimeType,
        wordCount: request.wordCount,
        model: fallbackProfile.model,
        systemPrompt: systemPrompt,
        profileId: fallbackProfile.id,
        substituteTargetLanguage: request.substituteTargetLanguage,
      );

      await _streamTranslation(
        provider: provider,
        request: fallbackRequest,
        stopwatch: stopwatch,
      );
      return true;
    } on TranslationException {
      // Retry failed — report the original error, not the retry error.
      state = TranslationError(originalError);
      return true;
    } on ResponsePathException {
      state = TranslationError(originalError);
      return true;
    } catch (e) {
      state = TranslationError(originalError);
      return true;
    }
  }

  /// Persists a completed translation to the history database.
  Future<void> _saveToHistory({
    required TranslationRequest request,
    required String fullText,
    required String modelUsed,
    required int durationMs,
  }) async {
    final historyService = HistoryService();
    await historyService.save(
      inputText: request.inputText,
      outputText: fullText,
      targetLanguage: request.targetLanguage,
      sourceLanguage: null,
      inputType: request.imageBase64 != null ? 'image' : 'text',
      modelUsed: modelUsed,
      wordCount: request.wordCount,
    );
  }
}
