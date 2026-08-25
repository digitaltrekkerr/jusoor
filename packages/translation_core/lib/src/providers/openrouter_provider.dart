import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions/translation_exception.dart';
import '../models/provider_profile.dart';
import '../models/translation_request.dart';
import '../models/translation_provider.dart';
import '../utils/sse_parser.dart';
import '../utils/variable_substitutor.dart';

/// Default OpenRouter API endpoint.
const _kDefaultEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

/// Default body template for OpenRouter chat completions.
const _kDefaultBodyTemplate =
    '{"model":"{{model}}","messages":[{"role":"system","content":"{{system_prompt}}"},{"role":"user","content":"{{input_text}}"}],"stream":true}';

/// Default headers for OpenRouter requests.
const _kDefaultHeaders = <String, String>{
  'Authorization': 'Bearer {{api_key}}',
  'Content-Type': 'application/json',
  'HTTP-Referer': 'https://github.com/digitaltrekkerr/jusoor',
  'X-Title': 'Jusoor',
};

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

  /// Custom body template. Defaults to the OpenRouter chat-completions
  /// template.
  final String bodyTemplate;

  /// Custom headers. Defaults to standard OpenRouter headers.
  final Map<String, String> headers;

  /// Dot-notation path for extracting content from streaming deltas.
  ///
  /// Defaults to `choices.0.delta.content`.
  final String streamingResponsePath;

  /// Dot-notation path for extracting content from non-streaming responses.
  ///
  /// Defaults to `choices.0.message.content`.
  final String nonStreamingResponsePath;

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

  /// Creates an [OpenRouterProvider].
  ///
  /// Only [apiKey] is required; all other parameters have sensible defaults
  /// for the OpenRouter API.
  OpenRouterProvider({
    required this.apiKey,
    Dio? dio,
    this.endpointUrl = _kDefaultEndpoint,
    this.bodyTemplate = _kDefaultBodyTemplate,
    this.headers = _kDefaultHeaders,
    this.streamingResponsePath = 'choices.0.delta.content',
    this.nonStreamingResponsePath = 'choices.0.message.content',
    this.stream = true,
    this.model,
    this.visionModel,
  }) : _dio = dio ?? Dio();

  /// Creates an [OpenRouterProvider] from a [ProviderProfile] and API key.
  ///
  /// Passes profile fields through to the default constructor:
  /// - [ProviderProfile.baseUrl] → [endpointUrl]
  /// - [ProviderProfile.model] → [model]
  /// - [ProviderProfile.visionModel] → [visionModel]
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
    );
  }

  @override
  Future<List<String>> fetchModels() async {
    try {
      final response = await _dio.get(
        'https://openrouter.ai/api/v1/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );
      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>;
      return models.map((m) => (m as Map<String, dynamic>)['id'] as String).toList();
    } on DioException catch (e) {
      throw TranslationException(e.message ?? 'Failed to fetch models', statusCode: e.response?.statusCode);
    } catch (e) {
      throw TranslationException('Unexpected error fetching models: $e');
    }
  }

  @override
  Stream<String> translate(TranslationRequest request) async* {
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
    final Map<String, dynamic> bodyJson;
    if (request.imageBase64 != null && request.imageBase64!.isNotEmpty) {
      bodyJson = _buildVisionBody(request);
    } else {
      final substitutedBody = VariableSubstitutor.substituteMap(
        bodyTemplate,
        variableMap,
        substituteTargetLanguage: request.substituteTargetLanguage,
      );
      bodyJson = jsonDecode(substitutedBody) as Map<String, dynamic>;
    }

    try {
      final response = await _dio.post<ResponseBody>(
        endpointUrl,
        data: bodyJson,
        options: Options(
          headers: substitutedHeaders,
          responseType: ResponseType.stream,
        ),
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw TranslationException('Empty response body');
      }

      final parser = SSEParser(responsePath: streamingResponsePath);

      await for (final chunk in responseBody.stream.cast<List<int>>().transform(
        utf8.decoder,
      )) {
        final contents = parser.parseChunk(chunk);
        for (final content in contents) {
          yield content;
        }
      }
    } on DioException catch (e) {
      throw TranslationException(
        e.message ?? 'HTTP request failed',
        statusCode: e.response?.statusCode,
      );
    } on TranslationException {
      rethrow;
    } catch (e) {
      throw TranslationException('Unexpected error: $e');
    }
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

    return {
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
                    'data:${request.imageMimeType ?? 'image/jpeg'};base64,${request.imageBase64}',
              },
            },
          ],
        },
      ],
      'stream': stream,
    };
  }
}
