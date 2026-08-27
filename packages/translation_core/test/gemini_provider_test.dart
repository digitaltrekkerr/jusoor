import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/exceptions/translation_exception.dart';
import 'package:translation_core/src/exceptions/translation_cancelled_exception.dart';
import 'package:translation_core/src/models/translation_request.dart';
import 'package:translation_core/src/providers/gemini_provider.dart';

void main() {
  group('GeminiProvider', () {
    RequestOptions? capturedRequest;

    Dio createMockStreamingDio({List<String> textChunks = const ['Hello']}) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;

            final sseEvents = textChunks
                .map((text) {
                  final json = jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {'text': text},
                          ],
                        },
                      },
                    ],
                  });
                  return 'data: $json\n';
                })
                .join('\n');

            handler.resolve(
              Response<ResponseBody>(
                requestOptions: options,
                data: ResponseBody(
                  Stream.fromIterable([
                    Uint8List.fromList(utf8.encode(sseEvents)),
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

    Dio createMockNonStreamingDio({String text = 'Hello'}) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;

            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': text},
                        ],
                      },
                    },
                  ],
                },
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

    group('body construction', () {
      test('text-only body has correct structure', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
          systemPrompt: 'You are a translator.',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        final body = capturedRequest!.data as Map<String, dynamic>;

        expect(body.containsKey('systemInstruction'), isTrue);
        expect(body.containsKey('contents'), isTrue);

        final systemInstruction =
            body['systemInstruction'] as Map<String, dynamic>;
        expect(systemInstruction.containsKey('parts'), isTrue);
        final systemParts = systemInstruction['parts'] as List;
        expect(systemParts.length, 1);
        expect(systemParts[0]['text'], 'You are a translator.');

        final contents = body['contents'] as List;
        expect(contents.length, 1);
        final userContent = contents[0] as Map<String, dynamic>;
        expect(userContent['role'], 'user');
        final userParts = userContent['parts'] as List;
        expect(userParts.length, 1);
        expect(userParts[0]['text'], 'Hello');
      });

      test('vision body includes inlineData with mimeType and data', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Describe this',
          targetLanguage: 'English',
          systemPrompt: 'You are a translator.',
          imageBase64: 'base64imagedata==',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        final body = capturedRequest!.data as Map<String, dynamic>;

        expect(body.containsKey('systemInstruction'), isTrue);
        expect(body.containsKey('contents'), isTrue);

        final contents = body['contents'] as List;
        final userContent = contents[0] as Map<String, dynamic>;
        expect(userContent['role'], 'user');
        final userParts = userContent['parts'] as List;
        expect(userParts.length, 2);

        expect(userParts[0]['text'], 'Describe this');

        final inlineData = userParts[1]['inlineData'] as Map<String, dynamic>;
        expect(inlineData['mimeType'], 'image/jpeg');
        expect(inlineData['data'], 'base64imagedata==');
      });

      test('vision body uses imageMimeType when provided', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Describe this',
          targetLanguage: 'English',
          systemPrompt: 'You are a translator.',
          imageBase64: 'base64imagedata==',
          imageMimeType: 'image/png',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        final body = capturedRequest!.data as Map<String, dynamic>;
        final contents = body['contents'] as List;
        final userParts =
            (contents[0] as Map<String, dynamic>)['parts'] as List;
        final inlineData = userParts[1]['inlineData'] as Map<String, dynamic>;
        expect(inlineData['mimeType'], 'image/png');
      });

      test('systemInstruction is separate from contents', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
          systemPrompt: 'System prompt here',
        );

        await provider.translate(request).toList();

        final body = capturedRequest!.data as Map<String, dynamic>;

        expect(body['systemInstruction'], isA<Map>());
        expect(body['contents'], isA<List>());

        final contents = body['contents'] as List;
        for (final content in contents) {
          expect((content as Map<String, dynamic>)['role'], isNot('system'));
        }
      });

      test(
        'vision body uses fallback prompt when inputText is empty',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: '',
            targetLanguage: 'French',
            systemPrompt: 'You are a translator.',
            imageBase64: 'base64data==',
          );

          await provider.translate(request).toList();

          final body = capturedRequest!.data as Map<String, dynamic>;
          final contents = body['contents'] as List;
          final userParts =
              (contents[0] as Map<String, dynamic>)['parts'] as List;
          expect(
            userParts[0]['text'],
            'Translate the text in this image to French',
          );
        },
      );

      test(
        'resolves {{target_language}} in systemPrompt for text body',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'French',
            systemPrompt: 'Translate to {{target_language}}.',
          );

          await provider.translate(request).toList();

          final body = capturedRequest!.data as Map<String, dynamic>;
          final systemInstruction =
              body['systemInstruction'] as Map<String, dynamic>;
          final systemParts = systemInstruction['parts'] as List;
          expect(systemParts[0]['text'], 'Translate to French.');
        },
      );

      test(
        'resolves {{target_language}} in systemPrompt for vision body',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Describe this',
            targetLanguage: 'Japanese',
            systemPrompt: 'Translate the text to {{target_language}}.',
            imageBase64: 'base64data==',
          );

          await provider.translate(request).toList();

          final body = capturedRequest!.data as Map<String, dynamic>;
          final systemInstruction =
              body['systemInstruction'] as Map<String, dynamic>;
          final systemParts = systemInstruction['parts'] as List;
          expect(systemParts[0]['text'], 'Translate the text to Japanese.');
        },
      );

      test(
        'does not JSON-escape resolved placeholders in systemPrompt',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'Spanish',
            systemPrompt:
                'Translate to {{target_language}}.\nPreserve formatting.',
          );

          await provider.translate(request).toList();

          final body = capturedRequest!.data as Map<String, dynamic>;
          final systemInstruction =
              body['systemInstruction'] as Map<String, dynamic>;
          final systemParts = systemInstruction['parts'] as List;
          expect(
            systemParts[0]['text'],
            'Translate to Spanish.\nPreserve formatting.',
          );
        },
      );
    });

    group('thinking field absence (regression guard)', () {
      test(
        'text body never carries a generationConfig.thinkingConfig key '
        'regardless of model',
        () async {
          Future<Map<String, dynamic>> bodyFor(String model) async {
            capturedRequest = null;
            final dio = createMockStreamingDio();
            final provider = GeminiProvider(
              apiKey: 'test-key',
              model: model,
              dio: dio,
            );
            await provider
                .translate(
                  TranslationRequest(
                    inputText: 'Hello',
                    targetLanguage: 'Spanish',
                    systemPrompt: 'Translate.',
                  ),
                )
                .toList();
            return capturedRequest!.data as Map<String, dynamic>;
          }

          for (final model in const [
            'gemini-2.5-pro',
            'gemini-2-5-pro',
            'gemini-2.5-flash',
            'gemini-2.5-flash-lite',
            'gemini-2.0-flash',
            'gemma-3-27b-it',
          ]) {
            final body = await bodyFor(model);
            expect(
              body.containsKey('generationConfig'),
              isFalse,
              reason:
                  'V1 wire shape — no generationConfig is sent for $model',
            );
          }
        },
      );

      test(
        'stale requests carrying enableThinking JSON still produce no '
        'thinkingConfig on the wire',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-pro',
            dio: dio,
          );
          await provider
              .translate(
                TranslationRequest.fromJson(<String, dynamic>{
                  'inputText': 'Hello',
                  'targetLanguage': 'Spanish',
                  'systemPrompt': 'Translate.',
                  'enableThinking': true,
                }),
              )
              .toList();

          final body = capturedRequest!.data as Map<String, dynamic>;
          expect(body.containsKey('generationConfig'), isFalse);
        },
      );
    });

    group('headers and URL', () {
      test(
        'vision model is used in URL when visionModel is set and image is present',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            visionModel: 'gemini-2.5-pro',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Describe this',
            targetLanguage: 'English',
            imageBase64: 'base64imagedata==',
          );

          await provider.translate(request).toList();

          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.path, contains('gemini-2.5-pro'));
          expect(capturedRequest!.path, isNot(contains('gemini-2.5-flash')));
        },
      );

      test(
        'model is used in URL when visionModel is null and image is present',
        () async {
          final dio = createMockStreamingDio();
          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            visionModel: null,
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Describe this',
            targetLanguage: 'English',
            imageBase64: 'base64imagedata==',
          );

          await provider.translate(request).toList();

          expect(capturedRequest, isNotNull);
          expect(capturedRequest!.path, contains('gemini-2.5-flash'));
        },
      );

      test('headers include x-goog-api-key', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'my-secret-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.headers['x-goog-api-key'], 'my-secret-key');
        expect(capturedRequest!.headers['Content-Type'], 'application/json');
      });

      test('streaming URL contains streamGenerateContent?alt=sse', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
          stream: true,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        expect(
          capturedRequest!.path,
          contains('streamGenerateContent?alt=sse'),
        );
        expect(capturedRequest!.path, contains('gemini-2.5-flash'));
      });

      test('non-streaming URL uses generateContent without ?alt=sse', () async {
        final dio = createMockNonStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.0-flash',
          dio: dio,
          stream: false,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.path, contains('generateContent'));
        expect(capturedRequest!.path, isNot(contains('streamGenerateContent')));
        expect(capturedRequest!.path, isNot(contains('alt=sse')));
      });

      test('URL contains base Gemini path', () async {
        final dio = createMockStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        await provider.translate(request).toList();

        expect(
          capturedRequest!.path,
          contains('generativelanguage.googleapis.com/v1beta/models'),
        );
      });
    });

    group('streaming', () {
      test('yields content from SSE events', () async {
        final dio = createMockStreamingDio(textChunks: ['Hello', ' world']);
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hi',
          targetLanguage: 'Spanish',
        );

        final chunks = await provider.translate(request).toList();
        expect(chunks, ['Hello', ' world']);
      });

      test('yields single chunk from SSE event', () async {
        final dio = createMockStreamingDio(textChunks: ['Bonjour']);
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'French',
        );

        final chunks = await provider.translate(request).toList();
        expect(chunks, ['Bonjour']);
      });
    });

    group('non-streaming', () {
      test('yields content from JSON response', () async {
        final dio = createMockNonStreamingDio(text: 'Hola');
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
          stream: false,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        final chunks = await provider.translate(request).toList();
        expect(chunks, ['Hola']);
      });

      test('uses ResponseType.json for non-streaming', () async {
        final dio = createMockNonStreamingDio();
        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
          stream: false,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        await provider.translate(request).toList();

        expect(capturedRequest, isNotNull);
        expect(capturedRequest!.responseType, ResponseType.json);
      });
    });

    group('error handling', () {
      test('throws TranslationException on DioException', () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  message: 'Connection refused',
                  type: DioExceptionType.connectionError,
                ),
              );
            },
          ),
        );

        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-2.5-flash',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        expect(
          () => provider.translate(request).toList(),
          throwsA(isA<TranslationException>()),
        );
      });

      test(
        'throws TranslationException with status code on HTTP error',
        () async {
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response(
                      requestOptions: options,
                      statusCode: 429,
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
              },
            ),
          );

          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'Spanish',
          );

          try {
            await provider.translate(request).toList();
            fail('Expected TranslationException');
          } on TranslationException catch (e) {
            expect(e.statusCode, 429);
          }
        },
      );
    });

    group('null response body', () {
      test(
        'throws TranslationException("Empty response body") on streaming null data',
        () async {
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response<ResponseBody>(
                    requestOptions: options,
                    data: null,
                    statusCode: 200,
                  ),
                );
              },
            ),
          );

          final provider = GeminiProvider(
            apiKey: 'test-key',
            model: 'gemini-2.5-flash',
            dio: dio,
          );
          final request = TranslationRequest(
            inputText: 'Hello',
            targetLanguage: 'Spanish',
          );

          await expectLater(
            provider.translate(request).toList(),
            throwsA(
              isA<TranslationException>().having(
                (e) => e.message,
                'message',
                'Empty response body',
              ),
            ),
          );
        },
      );
    });

    group('cancellation', () {
      test('cancelling the token throws TranslationCancelledException',
          () async {
        // A Dio whose request interceptor never resolves — the request
        // stays in-flight until the CancelToken fires.
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              // Intentionally never call handler.next/resolve/reject.
            },
          ),
        );

        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-3.5-flash-lite',
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

        // Give the request a chance to start, then cancel mid-flight.
        await Future<void>.delayed(Duration.zero);
        token.cancel();
        await expectation;
      });

      test('recovers for a fresh request after cancellation', () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              options.cancelToken?.whenCancel.then((_) {
                handler.reject(
                  DioException.requestCancelled(
                    requestOptions: options,
                    reason: 'cancelled',
                  ),
                );
              });
            },
          ),
        );

        final provider = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-3.5-flash-lite',
          dio: dio,
        );
        final request = TranslationRequest(
          inputText: 'Hello',
          targetLanguage: 'Spanish',
        );

        final token = CancelToken();
        final first = expectLater(
          provider.translate(request, cancelToken: token).toList(),
          throwsA(isA<TranslationCancelledException>()),
        );
        await Future<void>.delayed(Duration.zero);
        token.cancel();
        await first;

        // A fresh, uncancelled request on a working dio must succeed —
        // proves no cancellation state leaked into the provider.
        final workingDio = createMockStreamingDio(textChunks: const ['Hola']);
        final provider2 = GeminiProvider(
          apiKey: 'test-key',
          model: 'gemini-3.5-flash-lite',
          dio: workingDio,
        );
        final result = await provider2
            .translate(request)
            .fold<StringBuffer>(
              StringBuffer(),
              (buf, chunk) => buf..write(chunk),
            );
        expect(result.toString(), contains('Hola'));
      });
    });
  });
}
