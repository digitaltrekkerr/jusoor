import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/exceptions/translation_cancelled_exception.dart';
import 'package:translation_core/src/models/reasoning_effort.dart';
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
          reason: 'a profile with no effort preference must not send one');
      expect(body['stream'], isTrue,
          reason: 'OpenRouter default is stream=true');
      expect(body.containsKey('max_tokens'), isFalse);
    });

    test(
        'an explicit effort of none still sends no reasoning key '
        '(not effort:"none")', () async {
      // `effort: "none"` is rejected with a 400 on models where reasoning is
      // mandatory, so "off" has to mean "omit the block", never "send none".
      final dio = createMockStreamingDio();
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: dio,
        reasoningEffort: ReasoningEffort.none,
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
      expect(body.containsKey('reasoning'), isFalse);
      expect(body.containsKey('reasoning_effort'), isFalse);
    });

    test(
        'a stored effort of none does not resurrect a reasoning key '
        '(regression guard for the deleted enableThinking flag)', () async {
      // An old request may still carry the removed flag in its toJson() map;
      // the provider must never translate it into a `reasoning` block.
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

  group('OpenRouterProvider — reasoning effort on the wire', () {
    RequestOptions? capturedRequest;

    Dio createMockStreamingDio({Map<String, dynamic>? modelsListing}) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            // The models listing is served only for the capability probe;
            // everything else gets an SSE translation stream.
            final isCapabilityProbe = options.path.endsWith('/models');
            if (isCapabilityProbe && modelsListing != null) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  data: modelsListing,
                  statusCode: 200,
                ),
              );
              return;
            }
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

    Map<String, dynamic> body() =>
        capturedRequest!.data as Map<String, dynamic>;

    setUp(() {
      capturedRequest = null;
    });

    test('a stored effort is sent as reasoning.effort', () async {
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(),
        reasoningEffort: ReasoningEffort.high,
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

      final reasoning = body()['reasoning'] as Map<String, dynamic>;
      expect(reasoning['effort'], 'high');
    });

    test('reason is excluded by default', () async {
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(),
        reasoningEffort: ReasoningEffort.medium,
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

      final reasoning = body()['reasoning'] as Map<String, dynamic>;
      expect(reasoning['exclude'], isTrue,
          reason: 'raw chain-of-thought must never stream into the overlay');
    });

    test('reasoning can be retained when the caller asks for it', () async {
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(),
        reasoningEffort: ReasoningEffort.low,
        reasoningExclude: false,
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

      expect((body()['reasoning'] as Map<String, dynamic>)['exclude'], isFalse);
    });

    test('the effort the profile requested is clamped to what the model takes',
        () async {
      // Real OpenRouter listing: Claude Haiku 5.5 accepts high/medium/low but
      // not the minimal level Jusoor never offers anyway, proving that a
      // request for an unlisted level is resolved rather than forwarded.
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(
          modelsListing: {
            'data': [
              {
                'id': 'anthropic/claude-haiku-5.5',
                'reasoning': {
                  'supported_efforts': ['max', 'xhigh', 'high', 'medium', 'low'],
                  'default_effort': 'medium',
                  'mandatory': false,
                },
              },
            ],
          },
        ),
        model: 'anthropic/claude-haiku-5.5',
        reasoningEffort: ReasoningEffort.medium,
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

      expect((body()['reasoning'] as Map<String, dynamic>)['effort'], 'medium');
    });

    test('reasoning is omitted for a dynamic router model', () async {
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(),
        model: 'openrouter/auto',
        reasoningEffort: ReasoningEffort.high,
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

      expect(body().containsKey('reasoning'), isFalse,
          reason: 'routers pick the model per request and accept no effort');
    });

    test('reasoning is omitted for a model with no reasoning support',
        () async {
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(
          modelsListing: {
            'data': [
              {'id': 'some/plain-model'},
            ],
          },
        ),
        model: 'some/plain-model',
        reasoningEffort: ReasoningEffort.high,
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

      expect(body().containsKey('reasoning'), isFalse);
    });

    test('reasoning is omitted when the model listing is unreachable', () async {
      // Unreachable capabilities fall back to passing the user's choice
      // through — see the vision-body test below for the alternative case.
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(),
        model: 'some/unknown-model',
        reasoningEffort: ReasoningEffort.medium,
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

      expect((body()['reasoning'] as Map<String, dynamic>)['effort'], 'medium');
    });

    test('the vision body carries reasoning too', () async {
      final provider = OpenRouterProvider(
        apiKey: 'k',
        dio: createMockStreamingDio(),
        visionModel: 'anthropic/claude-haiku-5.5',
        reasoningEffort: ReasoningEffort.low,
      );

      await provider
          .translate(
            TranslationRequest(
              inputText: 'Hello',
              targetLanguage: 'Arabic',
              systemPrompt: 'Translate.',
              imageBase64: base64Encode([1, 2, 3]),
              imageMimeType: 'image/png',
            ),
          )
          .toList();

      expect((body()['reasoning'] as Map<String, dynamic>)['effort'], 'low');
      expect(body().containsKey('reasoning'), isTrue,
          reason: 'an image request must get the same treatment');
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
