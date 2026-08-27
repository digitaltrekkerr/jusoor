import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/exceptions/translation_cancelled_exception.dart';
import 'package:translation_core/src/models/translation_request.dart';
import 'package:translation_core/src/providers/openrouter_provider.dart';

void main() {
  group('OpenRouterProvider — wire body', () {
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

    test('default request — no reasoning key, no max_tokens cap, stream=true',
        () async {
      final dio = createMockStreamingDio();
      final provider = OpenRouterProvider(apiKey: 'k', dio: dio);

      await provider
          .translate(
            TranslationRequest(
              inputText: 'Hello',
              targetLanguage: 'Arabic',
              systemPrompt: 'Translate to {{target_language}}.',
            ),
          )
          .toList();

      final body = capturedRequest!.data as Map<String, dynamic>;
      expect(body.containsKey('reasoning'), isFalse,
          reason: 'V1 wire shape — reasoning/thinking must never appear');
      expect(body['stream'], isTrue,
          reason: 'OpenRouter default is stream=true');
      expect(body.containsKey('max_tokens'), isFalse);
    });

    test(
        'no reasoning key on the wire even when the request repeats an '
        'inert enableThinking JSON key (regression guard)', () async {
      // A stale request still in flight may carry the deleted flag in
      // its toJson() map; the provider must never translate it into a
      // `reasoning` block on the wire.
      final dio = createMockStreamingDio();
      final provider = OpenRouterProvider(apiKey: 'k', dio: dio);

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
      expect(body.containsKey('reasoning'), isFalse);
      expect(body.containsKey('reasoning_effort'), isFalse);
    });
  });

  group('OpenRouterProvider — text body escaping (C1)', () {
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

    test(
        'input text with quotes and newlines produces a JSON-parseable body',
        () async {
      final dio = createMockStreamingDio();
      final provider = OpenRouterProvider(apiKey: 'k', dio: dio);
      const inputText = 'Never say "I\'m ready"\nKeep learning.';
      const systemPrompt =
          'Translate to {{target_language}}. Never say "maybe".\nBe precise.';

      await provider
          .translate(
            TranslationRequest(
              inputText: inputText,
              targetLanguage: 'Arabic',
              systemPrompt: systemPrompt,
            ),
          )
          .toList();

      final body = capturedRequest!.data as Map<String, dynamic>;
      final roundTripped = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
      final messages = roundTripped['messages'] as List<dynamic>;
      expect(messages[0]['content'],
          'Translate to Arabic. Never say "maybe".\nBe precise.');
      expect(messages[1]['content'], inputText,
          reason: 'quoted/newline input must survive the JSON round-trip');
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

        final provider = OpenRouterProvider(apiKey: 'k', dio: dio);
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
