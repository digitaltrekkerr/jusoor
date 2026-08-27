import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/exceptions/translation_cancelled_exception.dart';
import 'package:translation_core/src/models/translation_request.dart';
import 'package:translation_core/src/providers/openai_compatible_provider.dart';

void main() {
  group('OpenAICompatibleProvider — wire body', () {
    RequestOptions? capturedRequest;

    Dio createMockStreamingDio() {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            final sse = 'data: {"choices":[{"delta":{"content":"Hi"}}]}\n\n';
            handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                data: ResponseBody(
                  Stream.fromIterable([
                    Uint8List.fromList(utf8.encode(sse)),
                  ]),
                  200,
                ),
                statusCode: 200,
              ),
            );
          },
        ),
      );
      return dio;
    }

    setUp(() {
      capturedRequest = null;
    });

    test('default request — no reasoning_effort, no max_tokens, stream=true',
        () async {
      final dio = createMockStreamingDio();
      final provider = OpenAICompatibleProvider(
        apiKey: 'k',
        baseUrl: 'https://api.example.com/v1',
        model: 'gpt-4o-mini',
        dio: dio,
      );

      await provider
          .translate(
            TranslationRequest(
              inputText: 'Hello',
              targetLanguage: 'Arabic',
              systemPrompt: 'Translate.',
            ),
          )
          .toList();

      final body = capturedRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('reasoning_effort'), isFalse,
          reason: 'V1 wire shape — reasoning/thinking must never appear');
      expect(body['stream'], isTrue,
          reason: 'OpenAI-compat default is stream=true');
      expect(body.containsKey('max_tokens'), isFalse);
    });

    test(
        'no reasoning_effort on the wire even when a stale request repeats '
        'the deleted enableThinking JSON key (regression guard)', () async {
      final dio = createMockStreamingDio();
      final provider = OpenAICompatibleProvider(
        apiKey: 'k',
        baseUrl: 'https://api.example.com/v1',
        model: 'o3-mini',
        dio: dio,
      );

      await provider
          .translate(
            TranslationRequest.fromJson(<String, dynamic>{
              'inputText': 'Hello',
              'targetLanguage': 'Arabic',
              'systemPrompt': 'Translate.',
              'enableThinking': true,
            }),
          )
          .toList();

      final body = capturedRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('reasoning_effort'), isFalse);
      expect(body.containsKey('reasoning'), isFalse);
    });

    group('cancellation', () {
      test('cancelling the token throws TranslationCancelledException',
          () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              // Never resolve — keeps the request in-flight.
            },
          ),
        );

        final provider = OpenAICompatibleProvider(
          apiKey: 'k',
          baseUrl: 'https://api.example.com/v1',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        final token = CancelToken();
        final expectation = expectLater(
          provider.translate(request, cancelToken: token).toList(),
          throwsA(isA<TranslationCancelledException>()),
        );
        await Future<void>.delayed(Duration.zero);
        token.cancel();
        await expectation;
      });
    });
  });
}
