// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions/translation_exception.dart';
import '../exceptions/translation_cancelled_exception.dart';
import '../models/model_capabilities.dart';
import '../models/provider_profile.dart';
import '../models/reasoning_effort.dart';
import '../models/translation_request.dart';
import '../models/translation_provider.dart';
import '../utils/dio_factory.dart';
import '../utils/dio_error_extractor.dart';
import '../utils/image_payload_guard.dart';
import '../utils/sse_parser.dart';
import '../utils/variable_substitutor.dart';

/// Default OpenRouter API endpoint.
const _kDefaultEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

/// Endpoint that lists every model and the parameters it accepts.
const _kModelsEndpoint = 'https://openrouter.ai/api/v1/models';

/// Default headers for OpenRouter requests.
const _kDefaultHeaders = <String, String>{
  'Authorization': 'Bearer {{api_key}}',
  'Content-Type': 'application/json',
  'HTTP-Referer': 'https://github.com/digitaltrekkerr/jusoor',
  'X-Title': 'Jusoor',
};

/// Dynamic router model IDs.
///
/// These pick the serving model at request time, so nothing can be known
/// about their reasoning support up front and the `reasoning` key is
/// meaningless to them. They are recognised by ID so no network round-trip is
/// needed before a translation.
const _kDynamicRouterModelIds = {'openrouter/auto', 'openrouter/free'};

/// [TranslationProvider] implementation for the OpenRouter API.
///
/// Sends streaming chat-completion requests to the OpenRouter endpoint using
/// [Dio] with [ResponseType.stream], parses the SSE response, and yields
/// extracted content chunks.
class OpenRouterProvider implements TranslationProvider {
  /// API key used for authentication.
  final String apiKey;

  /// Dio instance used for HTTP requests.
  final Dio _dio;

  /// Custom endpoint URL. Defaults to the OpenRouter API.
  final String endpointUrl;

  /// Custom headers. Defaults to standard OpenRouter headers.
  final Map<String, String> headers;

  /// Dot-notation path for extracting content from streaming deltas.
  ///
  /// Defaults to `choices.0.delta.content`.
  final String streamingResponsePath;

  /// Whether to request a streaming response.
  final bool stream;

  /// Optional model override from a [ProviderProfile].
  ///
  /// When non-null, this overrides the `{{model}}` variable in the body
  /// template, so the provider always uses this model regardless of the
  /// [TranslationRequest.model] value.
  final String? model;

  /// Optional vision model override from a [ProviderProfile].
  ///
  /// When non-null, this is used for multimodal (image) translation requests
  /// instead of [model].
  final String? visionModel;

  /// Reasoning effort requested by the originating [ProviderProfile].
  ///
  /// `null` means the profile expresses no preference, in which case no
  /// `reasoning` block is sent at all and the request is byte-identical to
  /// what earlier versions of Jusoor produced.
  final ReasoningEffort? reasoningEffort;

  /// Whether reasoning tokens are withheld from the response.
  final bool reasoningExclude;

  /// Capabilities reported by the models endpoint, keyed by model ID.
  ///
  /// Warm this with [fetchModelCapabilities] — the settings screen does so
  /// when the profile editor opens. A cold cache costs one extra request on
  /// the first translation rather than silently dropping the user's setting.
  final Map<String, ModelCapabilities> _capabilityCache = {};

  /// Creates an [OpenRouterProvider].
  ///
  /// Only [apiKey] is required; all other parameters have sensible defaults
  /// for the OpenRouter API.
  OpenRouterProvider({
    required this.apiKey,
    Dio? dio,
    this.endpointUrl = _kDefaultEndpoint,
    this.headers = _kDefaultHeaders,
    this.streamingResponsePath = 'choices.0.delta.content',
    this.stream = true,
    this.model,
    this.visionModel,
    this.reasoningEffort,
    this.reasoningExclude = true,
  }) : _dio = dio ?? createTranslationDio();

  /// Creates an [OpenRouterProvider] from a [ProviderProfile] and API key.
  ///
  /// Passes profile fields through to the default constructor:
  /// - [ProviderProfile.baseUrl] → [endpointUrl]
  /// - [ProviderProfile.model] → [model]
  /// - [ProviderProfile.visionModel] → [visionModel]
  /// - [ProviderProfile.reasoningEffort] → [reasoningEffort]
  /// - [ProviderProfile.reasoningExclude] → [reasoningExclude]
  factory OpenRouterProvider.fromProfile({
    required ProviderProfile profile,
    required String apiKey,
    Dio? dio,
  }) {
    return OpenRouterProvider(
      apiKey: apiKey,
      dio: dio,
      model: profile.model,
      visionModel: profile.visionModel,
      endpointUrl: profile.baseUrl ?? _kDefaultEndpoint,
      reasoningEffort: ReasoningEffort.fromWire(profile.reasoningEffort),
      reasoningExclude: profile.reasoningExclude,
    );
  }

  @override
  Future<List<String>> fetchModels() async {
    try {
      final response = await _dio.get(
        _kModelsEndpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>;
      return models
          .map((m) => (m as Map<String, dynamic>)['id'] as String)
          .toList();
    } on DioException catch (e) {
      throw TranslationException(
        describeDioError(e, provider: 'OpenRouter'),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw TranslationException('Unexpected error fetching models: $e');
    }
  }

  @override
  Future<List<ModelCapabilities>> fetchModelCapabilities() async {
    final response = await _dio.get(
      _kModelsEndpoint,
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final data = response.data;
    if (data is! Map<String, dynamic>) return const [];

    final models = data['data'];
    if (models is! List) return const [];

    final capabilities = <ModelCapabilities>[];
    for (final entry in models) {
      if (entry is! Map) continue;
      final parsed = _parseCapabilities(entry);
      if (parsed != null) capabilities.add(parsed);
    }

    // Warm the cache so a later translate() does not repeat the request.
    _capabilityCache
      ..clear()
      ..addEntries(capabilities.map((c) => MapEntry(c.id, c)));

    return capabilities;
  }

  /// Reads one entry of `GET /api/v1/models` into [ModelCapabilities].
  ///
  /// The shape is:
  ///
  /// ```json
  /// {
  ///   "id": "anthropic/claude-haiku-5.5",
  ///   "reasoning": {
  ///     "supported_efforts": ["max", "xhigh", "high", "medium", "low"],
  ///     "default_effort": "medium",
  ///     "default_enabled": true,
  ///     "mandatory": false
  ///   }
  /// }
  /// ```
  ///
  /// `supported_efforts` arrives in **descending** order. Non-reasoning and
  /// dynamic-router models omit the `reasoning` object entirely, which is
  /// exactly the signal that an effort selector must not be offered.
  ModelCapabilities? _parseCapabilities(Map<dynamic, dynamic> entry) {
    final id = entry['id'];
    if (id is! String || id.isEmpty) return null;

    final reasoning = entry['reasoning'];
    if (reasoning is! Map) {
      return ModelCapabilities(id: id, known: true, supportsReasoning: false);
    }

    final rawEfforts = reasoning['supported_efforts'];
    final efforts = <ReasoningEffort>[];
    if (rawEfforts is List) {
      for (final raw in rawEfforts) {
        if (raw is! String) continue;
        final effort = ReasoningEffort.fromWire(ReasoningEffort.normalize(raw).name);
        if (effort != null && !efforts.contains(effort)) efforts.add(effort);
      }
    }

    final defaultEffort = reasoning['default_effort'] is String
        ? ReasoningEffort.fromWire(
            ReasoningEffort.normalize(reasoning['default_effort'] as String).name,
          )
        : null;

    return ModelCapabilities(
      id: id,
      known: true,
      supportsReasoning: reasoning['default_enabled'] == true ||
          efforts.isNotEmpty ||
          reasoning['enabled'] == true ||
          reasoning['mandatory'] == true,
      reasoningMandatory: reasoning['mandatory'] == true,
      supportedEfforts: efforts,
      defaultEffort: defaultEffort,
      defaultEnabled: reasoning['default_enabled'] == true,
    );
  }

  /// Capabilities for [modelId], fetching them once if the cache is cold.
  ///
  /// Dynamic router IDs short-circuit to "unknown" without a request — they
  /// have no stable capability set to ask about.
  Future<ModelCapabilities> _capabilitiesFor(String modelId) async {
    final cached = _capabilityCache[modelId];
    if (cached != null) return cached;
    if (_kDynamicRouterModelIds.contains(modelId)) {
      // A router picks the serving model at request time, so it has no
      // stable capability set to consult — and nothing meaningful to send.
      // Reported as "known, not reasoning" so the `reasoning` key is
      // omitted rather than guessed at.
      return ModelCapabilities(id: modelId, known: true, supportsReasoning: false);
    }

    try {
      final capabilities = await fetchModelCapabilities();
      final found = capabilities.where((c) => c.id == modelId).firstOrNull;
      if (found != null) return found;
    } on DioException {
      // Unreachable or unauthorized. Fall through and let the user's own
      // choice stand rather than silently discarding it.
    } catch (_) {
      // Same reasoning: a malformed listing must not disable the feature.
    }

    return ModelCapabilities.unknown(modelId);
  }

  /// Builds the optional `reasoning` block for a request body.
  ///
  /// Returns `null` — meaning "send nothing" — whenever reasoning should not
  /// be mentioned on the wire:
  ///
  /// * the profile expresses no preference, or
  /// * the resolved effort is [ReasoningEffort.none]. `none` is deliberately
  ///   *not* sent as `effort: "none"`, which OpenRouter rejects on models
  ///   where reasoning is mandatory.
  ///
  /// `effort` and `max_tokens` are never sent together: OpenRouter accepts
  /// either but not both.
  Future<Map<String, dynamic>?> _buildReasoningBlock(String modelId) async {
    if (reasoningEffort == null) return null;

    final capabilities = await _capabilitiesFor(modelId);
    final resolved = capabilities.sanitize(reasoningEffort);
    if (resolved == ReasoningEffort.none) return null;

    return <String, dynamic>{
      'effort': resolved.wireValue,
      'exclude': reasoningExclude,
    };
  }

  @override
  Stream<String> translate(
    TranslationRequest request, {
    CancelToken? cancelToken,
  }) async* {
    if (request.inputText.trim().isEmpty &&
        (request.imageBase64 == null || request.imageBase64!.isEmpty)) {
      throw const TranslationException('Empty input: nothing to translate.');
    }

    // Reject an unusable image locally. The app resizes and recompresses
    // before this point; this guard means a regression there still fails
    // with a message the user can act on, instead of a 400 from Anthropic
    // that only manifests for some models.
    final imageBase64 = request.imageBase64;
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      final verdict = ImagePayloadGuard.check(imageBase64, request.imageMimeType);
      if (!verdict.isValid) {
        throw TranslationException(verdict.problem!);
      }
    }

    final variableMap = VariableSubstitutor.buildVariableMap(request, apiKey);
    // Override model with the provider's configured model if set.
    if (model != null) {
      variableMap['model'] = model!;
    }

    final substitutedHeaders = <String, String>{};
    for (final entry in headers.entries) {
      substitutedHeaders[entry.key] = VariableSubstitutor.substituteMap(
        entry.value,
        variableMap,
        substituteTargetLanguage: request.substituteTargetLanguage,
      );
    }

    // Build the request body. When an image is present, construct it
    // programmatically to produce a vision-compatible content array.
    final isVision = request.imageBase64 != null &&
        request.imageBase64!.isNotEmpty;
    final effectiveModel = isVision
        ? (visionModel ?? request.model)
        : (model ?? request.model);
    final reasoningBlock =
        await _buildReasoningBlock(effectiveModel);

    final Map<String, dynamic> bodyJson;
    if (isVision) {
      bodyJson = _buildVisionBody(request);
    } else {
      bodyJson = _buildTextBody(request);
    }
    if (reasoningBlock != null) {
      bodyJson['reasoning'] = reasoningBlock;
    }

    try {
      final response = await _dio.post<ResponseBody>(
        endpointUrl,
        data: bodyJson,
        options: Options(
          headers: substitutedHeaders,
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw TranslationException('Empty response body');
      }

      final parser = SSEParser(responsePath: streamingResponsePath);

      try {
        await for (final chunk in responseBody.stream.cast<List<int>>().transform(
          utf8.decoder,
        )) {
          final contents = parser.parseChunk(chunk);
          for (final content in contents) {
            yield content;
          }
        }
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          throw const TranslationCancelledException();
        }
        rethrow;
      }

      // Stream may end silently on cancel; surface it as a cancellation.
      if (cancelToken?.isCancelled == true) {
        throw const TranslationCancelledException();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const TranslationCancelledException();
      }
      final statusCode = e.response?.statusCode;
      final detail = describeDioError(e, provider: 'OpenRouter');

      // A vision request that fails almost always means the selected model
      // cannot take an image. Some gateways answer 404, others answer 400 —
      // Anthropic in particular rejects an oversized image with a bare
      // `invalid_request_error` rather than saying "no vision support".
      if (isVision && (statusCode == 404 || statusCode == 400)) {
        throw TranslationException(
          statusCode == 404
              ? 'The selected model does not support image translation. '
                  'Choose a vision-capable model (or switch to a text-only '
                  'request) and try again.'
              : 'This model rejected the image ($detail). It may not support '
                  'image input, or the image may exceed its limits. Try a '
                  'smaller or JPEG-compressed image, or pick a different '
                  'vision model.',
          statusCode: statusCode,
        );
      }

      throw TranslationException(detail, statusCode: statusCode);
    } on TranslationCancelledException {
      rethrow;
    } on TranslationException {
      rethrow;
    } catch (e) {
      throw TranslationException('Unexpected error: $e');
    }
  }

  /// Builds a text-only request body with system and user message content.
  ///
  /// The body is assembled programmatically as a `Map` so that quotes,
  /// newlines, and other special characters in user-supplied text are
  /// handled by the JSON serializer instead of being interpolated into a
  /// raw JSON template (which produced invalid JSON and threw a
  /// [FormatException] on `jsonDecode`).
  Map<String, dynamic> _buildTextBody(TranslationRequest request) {
    final resolvedPrompt = VariableSubstitutor.substituteMap(
      request.systemPrompt,
      VariableSubstitutor.buildRawVariableMap(request, apiKey),
      substituteTargetLanguage: request.substituteTargetLanguage,
    );

    return <String, dynamic>{
      'model': model ?? request.model,
      'messages': [
        {'role': 'system', 'content': resolvedPrompt},
        {'role': 'user', 'content': request.inputText},
      ],
      'stream': stream,
    };
  }

  /// Builds a vision-compatible request body with multimodal content blocks.
  ///
  /// The user message content is an array containing a text block and an
  /// image URL block, following the OpenRouter/OpenAI chat completions
  /// format for multimodal requests.
  Map<String, dynamic> _buildVisionBody(TranslationRequest request) {
    final effectiveModel = visionModel ?? request.model;
    final resolvedPrompt = VariableSubstitutor.substituteMap(
      request.systemPrompt,
      VariableSubstitutor.buildRawVariableMap(request, apiKey),
      substituteTargetLanguage: request.substituteTargetLanguage,
    );

    return <String, dynamic>{
      'model': effectiveModel,
      'messages': [
        {'role': 'system', 'content': resolvedPrompt},
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': request.inputText.isNotEmpty
                  ? request.inputText
                  : 'Translate the text in this image to ${request.targetLanguage}',
            },
            {
              'type': 'image_url',
              'image_url': {
                'url':
                    'data:${ImagePayloadGuard.normalizeMimeType(request.imageMimeType)};'
                    'base64,${request.imageBase64}',
              },
            },
          ],
        },
      ],
      'stream': stream,
    };
  }
}
