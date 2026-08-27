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

const _kBaseGeminiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models';

const _kGeminiResponsePath = 'candidates.0.content.parts.0.text';

class GeminiProvider implements TranslationProvider {
  final String apiKey;

  final String model;

  final Dio _dio;

  final String? visionModel;

  final bool stream;

  GeminiProvider({
    required this.apiKey,
    required this.model,
    Dio? dio,
    this.stream = true,
    this.visionModel,
  }) : _dio = dio ?? createTranslationDio();

  String _buildEndpointUrl(String modelToUse) {
    if (stream) {
      return '$_kBaseGeminiUrl/$modelToUse:streamGenerateContent?alt=sse';
    }
    return '$_kBaseGeminiUrl/$modelToUse:generateContent';
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-goog-api-key': apiKey,
  };

  @override
  Future<List<String>> fetchModels() async {
    try {
      final response = await _dio.get(
        _kBaseGeminiUrl,
        options: Options(headers: _headers),
      );
      final data = response.data as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>;
      return models.map((m) {
        final name = (m as Map<String, dynamic>)['name'] as String;
        return name.startsWith('models/') ? name.substring(7) : name;
      }).toList();
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
    final isVision =
        request.imageBase64 != null && request.imageBase64!.isNotEmpty;
    final effectiveModel = isVision ? (visionModel ?? model) : model;
    final bodyJson = isVision
        ? _buildVisionBody(request)
        : _buildTextBody(request);

    try {
      if (stream) {
        yield* _handleStreamResponse(effectiveModel, bodyJson, cancelToken);
      } else {
        yield await _handleNonStreamResponse(
          effectiveModel,
          bodyJson,
          cancelToken,
        );
      }
    } on TranslationCancelledException {
      rethrow;
    } on TranslationException {
      rethrow;
    } catch (e) {
      throw TranslationException('Unexpected error: $e');
    }
  }

  Stream<String> _handleStreamResponse(
    String effectiveModel,
    Map<String, dynamic> bodyJson,
    CancelToken? cancelToken,
  ) async* {
    final ResponseBody? responseBody;
    try {
      final response = await _dio.post<ResponseBody>(
        _buildEndpointUrl(effectiveModel),
        data: bodyJson,
        options: Options(headers: _headers, responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      responseBody = response.data;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const TranslationCancelledException();
      }
      throw TranslationException(
        e.message ?? 'HTTP request failed',
        statusCode: e.response?.statusCode,
      );
    }

    if (responseBody == null) {
      throw const TranslationException('Empty response body');
    }

    final parser = SSEParser(responsePath: _kGeminiResponsePath);

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

    // Stream may end silently on cancel (e.g. server closes the connection
    // without a DioException); surface it as a cancellation.
    if (cancelToken?.isCancelled == true) {
      throw const TranslationCancelledException();
    }
  }

  Future<String> _handleNonStreamResponse(
    String effectiveModel,
    Map<String, dynamic> bodyJson,
    CancelToken? cancelToken,
  ) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.post<Map<String, dynamic>>(
        _buildEndpointUrl(effectiveModel),
        data: bodyJson,
        options: Options(headers: _headers, responseType: ResponseType.json),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const TranslationCancelledException();
      }
      throw TranslationException(
        e.message ?? 'HTTP request failed',
        statusCode: e.response?.statusCode,
      );
    }

    final responseData = response.data;
    if (responseData == null) {
      throw const TranslationException('Empty response body');
    }

    return ResponsePathExtractor.extract(responseData, _kGeminiResponsePath);
  }

  Map<String, dynamic> _buildTextBody(TranslationRequest request) {
    final resolvedPrompt = VariableSubstitutor.substituteMap(
      request.systemPrompt,
      VariableSubstitutor.buildRawVariableMap(request),
      substituteTargetLanguage: request.substituteTargetLanguage,
    );
    return {
      'systemInstruction': {
        'parts': [
          {'text': resolvedPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': request.inputText},
          ],
        },
      ],
    };
  }

  Map<String, dynamic> _buildVisionBody(TranslationRequest request) {
    final resolvedPrompt = VariableSubstitutor.substituteMap(
      request.systemPrompt,
      VariableSubstitutor.buildRawVariableMap(request),
      substituteTargetLanguage: request.substituteTargetLanguage,
    );
    return {
      'systemInstruction': {
        'parts': [
          {'text': resolvedPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': request.inputText.isNotEmpty
                  ? request.inputText
                  : 'Translate the text in this image to ${request.targetLanguage}',
            },
            {
              'inlineData': {
                'mimeType': request.imageMimeType ?? 'image/jpeg',
                'data': request.imageBase64,
              },
            },
          ],
        },
      ],
    };
  }
}
