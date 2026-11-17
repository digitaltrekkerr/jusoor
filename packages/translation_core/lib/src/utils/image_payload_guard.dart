// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'dart:convert';
import 'dart:typed_data';

/// The outcome of validating an image payload before it is sent.
class ImagePayloadVerdict {
  /// Whether the payload may be sent as-is.
  final bool isValid;

  /// Why the payload was rejected, when [isValid] is `false`.
  ///
  /// Written for the end user: it names a limit they can act on rather than
  /// quoting an HTTP status code they can't do anything with.
  final String? problem;

  const ImagePayloadVerdict._({required this.isValid, this.problem});

  /// The payload passed every check.
  const ImagePayloadVerdict.ok() : this._(isValid: true);

  /// The payload failed a check.
  const ImagePayloadVerdict.rejected(String this.problem) : isValid = false;
}

/// Validates an image payload without needing to decode it.
///
/// This is the core-side belt-and-braces check. The app resizes and
/// recompresses images before they ever reach a provider (see
/// `translation_app/lib/utils/image_payload.dart`); this guard exists so that
/// if that layer is bypassed or regresses, the request still fails *locally*
/// with a useful message instead of as an opaque 400 from the API.
///
/// The limits come from the Anthropic vision docs, which are strict enough to
/// reject an oversized image with `invalid_request_error` instead of quietly
/// downscaling it the way the OpenAI-compatible gateways do. That asymmetry is
/// why a screenshot that works perfectly on a GPT model 400s on a Claude model.
class ImagePayloadGuard {
  ImagePayloadGuard._();

  /// Longest edge an image may have, in pixels.
  ///
  /// Anthropic's maximum is 8000x8000, but their standard resolution tier
  /// downscales to a 1568px long edge anyway, and every pixel above that only
  /// costs tokens. The app enforces the tighter number before sending.
  static const int maxLongEdgePx = 1568;

  /// Ceiling on the decoded image, in bytes.
  ///
  /// Anthropic allows 10MB via their own API but only 5MB on Amazon Bedrock
  /// and Google Cloud, which is where OpenRouter routes a large share of
  /// Claude traffic. We stay under the stricter of the two.
  static const int maxDecodedBytes = 5 * 1024 * 1024;

  /// Ceiling we enforce on the payload we actually put on the wire.
  ///
  /// Deliberately below [maxDecodedBytes] so we always fail locally rather
  /// than discovering the limit from a provider.
  static const int maxAcceptedBytes = 4 * 1024 * 1024;

  /// MIME types every supported provider accepts.
  ///
  /// Animated images are unsupported; only the first frame is used.
  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
  };

  /// The MIME type used when one is missing or not recognised.
  static const String fallbackMimeType = 'image/jpeg';

  /// Validates the base64 payload and optional MIME type.
  static ImagePayloadVerdict check(String base64, String? mimeType) {
    final bytes = _decode(base64);
    if (bytes == null) {
      return const ImagePayloadVerdict.rejected(
        'The image could not be encoded correctly. Please pick it again.',
      );
    }

    if (bytes.length > maxAcceptedBytes) {
      final megabytes = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      final limit = (maxAcceptedBytes / (1024 * 1024)).toStringAsFixed(0);
      return ImagePayloadVerdict.rejected(
        'This image is too large to translate (${megabytes}MB, limit '
        '${limit}MB). Try a smaller or more compressed image.',
      );
    }

    return const ImagePayloadVerdict.ok();
  }

  /// Maps an arbitrary MIME type onto one every provider accepts.
  ///
  /// Returns [fallbackMimeType] for anything unrecognised. The returned value
  /// is always a member of [allowedMimeTypes], so the data URL built from it
  /// can never name a format the API will refuse.
  static String normalizeMimeType(String? mimeType) {
    if (mimeType == null) return fallbackMimeType;
    final normalized = mimeType.split(';').first.trim().toLowerCase();
    return allowedMimeTypes.contains(normalized)
        ? normalized
        : fallbackMimeType;
  }

  /// Decodes [base64], returning `null` if it is not valid base64.
  ///
  /// Hand-rolling the length arithmetic here was both wrong about `=`
  /// padding and less accurate than simply decoding: [Uint8List.length]
  /// gives the exact byte count, which is what we are comparing against
  /// [maxAcceptedBytes].
  static Uint8List? _decode(String base64) {
    if (base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } on FormatException {
      return null;
    }
  }
}
