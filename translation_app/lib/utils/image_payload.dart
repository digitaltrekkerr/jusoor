import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:translation_core/translation_core.dart';

/// The result of preparing an image for a translation request.
class PreparedImage {
  /// The base64-encoded, resized payload.
  final String base64;

  /// The MIME type matching [base64].
  ///
  /// Always consistent with the payload — a data URL built from this can
  /// never claim a format the bytes are not in.
  final String mimeType;

  /// Whether the image was altered on its way through.
  ///
  /// `false` means the original already satisfied every limit and was passed
  /// through untouched, so no fidelity was lost.
  final bool wasModified;

  const PreparedImage({
    required this.base64,
    required this.mimeType,
    required this.wasModified,
  });
}

/// Resizes and validates images before they are sent to a translation
/// provider.
///
/// Exists because of a real asymmetry between providers. OpenAI-compatible
/// gateways silently downscale an oversized image. Anthropic **rejects** one
/// with `invalid_request_error` once it passes 8000×8000 px or 5 MB of base64
/// — and 5 MB is the limit on Amazon Bedrock and Google Cloud, which is where
/// a large share of Claude traffic on OpenRouter is served.
///
/// The app was sending raw, native-resolution PNG screenshots with no size
/// check anywhere, so the same screenshot translated fine on a GPT model and
/// failed with a bare 400 on `anthropic/claude-haiku-5.5`. Doing the work here
/// fixes it for every provider at once, shrinks the request by roughly an
/// order of magnitude, and caps the token cost: a 1568 px long edge is exactly
/// Anthropic's standard resolution tier.
class ImagePayloadPreparer {
  ImagePayloadPreparer._();

  /// Longest edge an image may keep, in pixels.
  static const int maxLongEdgePx = 1568;

  /// Ceiling on the bytes we are willing to put on the wire.
  ///
  /// Deliberately below [ImagePayloadGuard.maxAcceptedBytes] so this class is
  /// the thing that fails, with rungs left to try, rather than the guard
  /// rejecting it later with nothing left.
  static const int targetBytes = 3 * 1024 * 1024;

  /// Long-edge rungs tried in order while the payload is still too heavy.
  static const List<int> _longEdgeLadder = [maxLongEdgePx, 1280, 1024];

  /// Prepares [bytes] for sending, preserving aspect ratio.
  ///
  /// Never throws. An image that already fits every limit, cannot be decoded,
  /// or stays too large after every rung comes back matching the original
  /// bytes, so [ImagePayloadGuard] produces the user-facing message rather
  /// than this class guessing at one.
  static Future<PreparedImage> prepare(
    Uint8List bytes, {
    String? mimeType,
  }) async {
    final original = PreparedImage(
      base64: base64Encode(bytes),
      mimeType: ImagePayloadGuard.normalizeMimeType(mimeType),
      wasModified: false,
    );

    final dimensions = await _dimensionsOf(bytes);
    if (dimensions == null) {
      // Undecodable. Pass it through and let the guard report it.
      return original;
    }

    final longestEdge = max(dimensions.width, dimensions.height).round();
    if (longestEdge <= maxLongEdgePx && bytes.length <= targetBytes) {
      return original;
    }

    for (final longEdge in _longEdgeLadder) {
      if (longEdge >= longestEdge) continue;
      final scaled = await _encodeScaledPng(
        bytes,
        dimensions: dimensions,
        longEdge: longEdge,
      );
      if (scaled == null || scaled.isEmpty) continue;
      if (scaled.length <= targetBytes) {
        return PreparedImage(
          base64: base64Encode(scaled),
          mimeType: 'image/png',
          wasModified: true,
        );
      }
    }

    return original;
  }

  /// Whether [bytes] already satisfies every limit and needs no work.
  static bool isWithinLimits(Uint8List bytes) => bytes.length <= targetBytes;

  /// The pixel dimensions of [bytes], or `null` if it cannot be decoded.
  static Future<Size?> _dimensionsOf(Uint8List bytes) async {
    final image = await _decode(bytes);
    if (image == null) return null;
    try {
      return Size(image.width.toDouble(), image.height.toDouble());
    } finally {
      image.dispose();
    }
  }

  /// Re-encodes [bytes] as a PNG whose longest edge is [longEdge], or `null`
  /// when the image cannot be decoded.
  ///
  /// `instantiateImageCodec` does the downscaling during decode, which is
  /// considerably cheaper than decoding at full size and scaling afterwards.
  ///
  /// Landscapes are scaled by width and portraits by height; passing only one
  /// makes the codec derive the other from the real aspect ratio, so the
  /// image is never stretched.
  static Future<Uint8List?> _encodeScaledPng(
    Uint8List bytes, {
    required Size dimensions,
    required int longEdge,
  }) async {
    final isLandscape = dimensions.width >= dimensions.height;
    try {
      final codec = await instantiateImageCodec(
        bytes,
        targetWidth: isLandscape ? longEdge : null,
        targetHeight: isLandscape ? null : longEdge,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } on Object {
      return null;
    }
  }

  /// Decodes [bytes] into a disposable image, or `null` on failure.
  static Future<Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } on Object {
      return null;
    }
  }
}
