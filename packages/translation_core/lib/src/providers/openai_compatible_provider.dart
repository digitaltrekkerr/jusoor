// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'dart:convert';

import 'package:dio/dio.dart';

import '../exceptions/translation_exception.dart';
import '../exceptions/translation_cancelled_exception.dart';
import '../models/translation_request.dart';
import '../models/translation_provider.dart';
import '../utils/dio_factory.dart';
import '../utils/response_path_extractor.dart';
import '../utils/sse_parser.dart';
import '../utils/variable_substitutor.dart';

const _kDefaultBodyTemplate =
    '{"model":"{{model}}","messages":[{"role":"system","content":"{{system_prompt}}"},{"role":"user","content":"{{input_text}}"}],"stream":true}';

const _kDefaultHeaders = <String, String>{
  'Authorization': 'Bearer {{api_key}}',
  'Content-Type': 'application/json',
};

const _kDefaultStreamingResponsePath = 'choices.0.delta.content';

const _kDefaultNonStreamingResponsePath = 'choices.0.message.content';

class OpenAICompatibleProvider implements TranslationProvider {
  final String apiKey;

  final String baseUrl;

  final String model;

  final String? visionModel;

  final bool stream;

  final Dio _dio;

  OpenAICompatibleProvider({
    required this.apiKey,
    required this.baseUrl,
    this.model = 'gpt-3.5-turbo',
    this.visionModel,
    this.stream = true,
    Dio? dio,
  }) : _dio = dio ?? createTranslationDio();

  String get _endpointUrl {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$base/chat/completions';
  }

  @override
  Future<List<String>> fetchModels() async {
    try {
      final response = await _dio.get(
        _endpointUrl.replaceFirst('/chat/completions', '/models'),
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
        e.message ?? 'Failed to fetch models',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw TranslationException('Unexpected error fetching models: $e');
    }
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
    final variableMap = VariableSubstitutor.buildVariableMap(request, apiKey);
    variableMap['model'] = model;

    final substitutedHeaders = <String, String>{};
    for (final entry in _kDefaultHeaders.entries) {
      substitutedHeaders[entry.key] = VariableSubstitutor.substituteMap(
        entry.value,
        variableMap,
        substituteTargetLanguage: request.substituteTargetLanguage,
      );
    }
    substitutedHeaders.putIfAbsent('Content-Type', () => 'application/json');

    final Map<String, dynamic> bodyJson;
    if (request.imageBase64 != null && request.imageBase64!.isNotEmpty) {
      bodyJson = _buildVisionBody(request);
    } else {
      final substitutedBody = VariableSubstitutor.substituteMap(
        _kDefaultBodyTemplate,
        variableMap,
        substituteTargetLanguage: request.substituteTargetLanguage,
      );
      bodyJson = jsonDecode(substitutedBody) as Map<String, dynamic>;
      // The generic body template hardcodes "stream":true; override it with
      // the provider's actual [stream] flag so non-streaming requests send
      // a truthful body to the endpoint.
      bodyJson['stream'] = stream;
    }

    final isStreaming = bodyJson['stream'] == true;

    try {
      final response = await _dio.post<ResponseBody>(
        _endpointUrl,
        data: bodyJson,
        options: Options(
          headers: substitutedHeaders,
          responseType: isStreaming ? ResponseType.stream : ResponseType.json,
        ),
        cancelToken: cancelToken,
      );

      if (isStreaming) {
        yield* _handleStreamResponse(response.data, cancelToken);
      } else {
        final dynamic responseData = response.data;
        if (responseData is ResponseBody) {
          yield* _handleStreamResponse(responseData, cancelToken);
        } else if (responseData is Map<String, dynamic>) {
          yield ResponsePathExtractor.extract(
            responseData,
            _kDefaultNonStreamingResponsePath,
          );
        } else {
          throw const TranslationException(
            'Unexpected response type for non-streaming request',
          );
        }
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const TranslationCancelledException();
      }
      throw TranslationException(
        e.message ?? 'HTTP request failed',
        statusCode: e.response?.statusCode,
      );
    } on TranslationCancelledException {
      rethrow;
    } on TranslationException {
      rethrow;
    } catch (e) {
      throw TranslationException('Unexpected error: $e');
    }
  }

  Map<String, dynamic> _buildVisionBody(TranslationRequest request) {
    final effectiveModel = visionModel ?? model;
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
                    'data:${request.imageMimeType ?? 'image/jpeg'};base64,${request.imageBase64}',
              },
            },
          ],
        },
      ],
      'stream': stream,
    };
  }

  Stream<String> _handleStreamResponse(
    ResponseBody? responseBody,
    CancelToken? cancelToken,
  ) async* {
    if (responseBody == null) {
      throw const TranslationException('Empty response body');
    }

    final parser = SSEParser(responsePath: _kDefaultStreamingResponsePath);

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
  }
}
