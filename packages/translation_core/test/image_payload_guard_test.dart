// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_core/src/utils/image_payload_guard.dart';

void main() {
  group('ImagePayloadGuard.check — accepts', () {
    test('a small valid payload', () {
      final verdict =
          ImagePayloadGuard.check(base64Encode([1, 2, 3, 4]), 'image/png');

      expect(verdict.isValid, isTrue);
      expect(verdict.problem, isNull);
    });

    test('a payload with no MIME type at all', () {
      expect(ImagePayloadGuard.check(base64Encode([9]), null).isValid, isTrue);
    });
  });

  group('ImagePayloadGuard.check — rejects', () {
    test('invalid base64', () {
      final verdict = ImagePayloadGuard.check('not base64!!', 'image/png');

      expect(verdict.isValid, isFalse);
      expect(verdict.problem, contains('could not be encoded'));
    });

    test('an empty payload', () {
      expect(ImagePayloadGuard.check('', 'image/png').isValid, isFalse);
    });

    test('an image larger than the accepted ceiling', () {
      // Just over maxAcceptedBytes (4MB) of real bytes.
      final bytes = Uint8List(ImagePayloadGuard.maxAcceptedBytes + 1);
      final verdict = ImagePayloadGuard.check(base64Encode(bytes), 'image/png');

      expect(verdict.isValid, isFalse);
      expect(verdict.problem, contains('too large'));
      expect(verdict.problem, contains('4MB'), reason: 'names the limit');
    });

    test('the ceiling sits safely below the stricter provider limit', () {
      expect(
        ImagePayloadGuard.maxAcceptedBytes,
        lessThan(ImagePayloadGuard.maxDecodedBytes),
        reason: 'fail locally rather than at the API',
      );
    });
  });

  group('ImagePayloadGuard.normalizeMimeType', () {
    test('passes through a recognised type', () {
      expect(ImagePayloadGuard.normalizeMimeType('image/webp'), 'image/webp');
    });

    test('strips parameters such as charset', () {
      expect(
        ImagePayloadGuard.normalizeMimeType('image/jpeg; charset=utf-8'),
        'image/jpeg',
      );
    });

    test('is case-insensitive', () {
      expect(ImagePayloadGuard.normalizeMimeType('IMAGE/PNG'), 'image/png');
    });

    test('coerces an unknown type to a safe default', () {
      expect(ImagePayloadGuard.normalizeMimeType('image/tiff'), 'image/jpeg');
      expect(ImagePayloadGuard.normalizeMimeType(''), 'image/jpeg');
      expect(ImagePayloadGuard.normalizeMimeType(null), 'image/jpeg');
    });

    test('always returns a member of the whitelist', () {
      for (final candidate in ['image/bmp', 'application/pdf', null, '']) {
        expect(
          ImagePayloadGuard.allowedMimeTypes
              .contains(ImagePayloadGuard.normalizeMimeType(candidate)),
          isTrue,
          reason: 'the data URL must never name a refused format',
        );
      }
    });
  });
}
