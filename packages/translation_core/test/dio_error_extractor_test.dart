// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/utils/dio_error_extractor.dart';

/// Builds the Dio that blew up, the way Dio itself does: the generic
/// `validateStatus` message, with the real reason buried in `response.data`.
DioException dioExceptionWith({
  int statusCode = 400,
  Object? data,
  String? message,
}) {
  final requestOptions = RequestOptions(path: 'https://openrouter.ai/api/v1');
  return DioException(
    requestOptions: requestOptions,
    response: Response<dynamic>(
      requestOptions: requestOptions,
      statusCode: statusCode,
      data: data,
    ),
    type: DioExceptionType.badResponse,
    message: message ??
        'This exception was thrown because the response has a status code of '
            '$statusCode and RequestOptions.validateStatus was configured to '
            'throw for this status code.',
  );
}

void main() {
  group('describeDioError — OpenRouter shape', () {
    test('surfaces error.message, which DioException.message never contains', () {
      final e = dioExceptionWith(
        data: {
          'error': {
            'message': 'Invalid model: no such provider route',
            'code': 400,
            'metadata': {'provider_name': 'anthropic'},
          },
        },
      );

      final described = describeDioError(e, provider: 'OpenRouter');

      expect(described, contains('OpenRouter 400'));
      expect(described, contains('Invalid model: no such provider route'));
      expect(
        described,
        isNot(contains('validateStatus')),
        reason: 'the whole point is to replace Dio\'s boilerplate',
      );
    });

    test('prefers error.message over error.metadata.raw', () {
      final e = dioExceptionWith(
        data: {
          'error': {
            'message': 'top level reason',
            'metadata': {'raw': '{"nested":"ignored"}'},
          },
        },
      );

      expect(describeDioError(e), contains('top level reason'));
    });

    test('falls back to error.metadata.raw when there is no message', () {
      final e = dioExceptionWith(
        data: {
          'error': {'metadata': {'raw': 'upstream said: rate limited'}},
        },
      );

      expect(describeDioError(e), contains('upstream said: rate limited'));
    });
  });

  group('describeDioError — Gemini shape', () {
    test('surfaces the nested error message', () {
      final e = dioExceptionWith(
        data: {
          'error': {
            'code': 400,
            'message': 'API key not valid. Please pass a valid API key.',
            'status': 'INVALID_ARGUMENT',
          },
        },
      );

      final described = describeDioError(e, provider: 'Gemini');

      expect(described, contains('Gemini 400'));
      expect(described, contains('API key not valid'));
    });
  });

  group('describeDioError — awkward bodies', () {
    test('string body that is really JSON error', () {
      final e = dioExceptionWith(
        data: '{"error":{"message":"string-encoded reason"}}',
      );

      expect(describeDioError(e), contains('string-encoded reason'));
    });

    test('HTML error page is stripped to readable text', () {
      final e = dioExceptionWith(
        data: '<html><body><h1>502 Bad Gateway</h1>'
            '<p>nginx</p></body></html>',
      );

      final described = describeDioError(e);
      expect(described, isNot(contains('<')));
      expect(described, contains('502 Bad Gateway'));
    });

    test('list body concatenates each reason', () {
      final e = dioExceptionWith(
        data: [
          {'error': {'message': 'first problem'}},
          {'error': {'message': 'second problem'}},
        ],
      );

      final described = describeDioError(e);
      expect(described, contains('first problem'));
      expect(described, contains('second problem'));
    });

    test('unparseable map body is serialized rather than dropped', () {
      final e = dioExceptionWith(data: {'unexpected': 'shape', 'code': 7});

      expect(describeDioError(e), contains('unexpected'));
      expect(describeDioError(e), contains('shape'));
    });

    test('empty data falls back to Dio message', () {
      final e = dioExceptionWith(data: null);

      expect(describeDioError(e), contains('validateStatus'));
    });

    test('omits the provider label when none is supplied', () {
      final e = dioExceptionWith(data: {'error': {'message': 'boom'}});

      final described = describeDioError(e);

      expect(described, startsWith('400: '));
      expect(described, isNot(contains('OpenRouter')));
    });

    test('connection error without a status code keeps the reason only', () {
      final requestOptions = RequestOptions(path: 'https://openrouter.ai');
      final e = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      );

      expect(describeDioError(e), 'Connection timed out');
      expect(describeDioError(e), isNot(contains('null')));
    });
  });

  group('describeDioError — length cap', () {
    test('an enormous reason is truncated', () {
      final e = dioExceptionWith(
        data: {'error': {'message': 'x' * 5000}},
      );

      expect(
        describeDioError(e).length,
        lessThanOrEqualTo(kMaxExtractedErrorLength),
      );
    });
  });
}
