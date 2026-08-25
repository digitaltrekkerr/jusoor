import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/exceptions/translation_exception.dart';
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
            systemPrompt:
                'Translate to {{target_language}}.',
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
  });
}
