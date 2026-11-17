// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'dart:convert';

import 'package:dio/dio.dart';

/// Maximum length of a provider error body we will surface to the user.
///
/// A single gateway can return several kilobytes of nested JSON metadata;
/// none of it is actionable and it will happily overflow a snackbar.
const int kMaxExtractedErrorLength = 500;

/// Turns a [DioException] into a message that tells the user *why* a request
/// failed.
///
/// `DioException.message` for a non-2xx response is a generic blurb about
/// `RequestOptions.validateStatus` — it never contains the provider's actual
/// reason. That reason lives in `e.response!.data`, which the providers used
/// to discard entirely. This class recovers it.
///
/// Handles the three shapes providers actually use:
///
/// * `{"error":{"message":"…","code":400,"metadata":{"provider_name":"…"}}}`
///   — OpenRouter, and most OpenAI-compatible gateways
/// * `{"error":{"code":400,"message":"…","status":"INVALID_ARGUMENT"}}`
///   — Google Gemini
/// * a bare string or an HTML error page
String describeDioError(DioException e, {String? provider}) {
  final data = e.response?.data;
  final reason = _extractReason(data) ??
      _cleanFallback(e.message) ??
      'HTTP request failed';

  final code = e.response?.statusCode;
  final label = provider == null ? '' : '$provider ';
  final prefix = code == null ? label : '$label$code: ';

  // Truncate the finished string so the prefix is included in the budget.
  return _truncate('$prefix$reason');
}

/// Caps [reason] at [kMaxExtractedErrorLength].
///
/// The trailing ellipsis is counted, so an over-long reason is cut at
/// `kMaxExtractedErrorLength - 1`. Applied to every path, including a `Map`
/// body: a provider is free to return several kilobytes of nested metadata,
/// and none of it is actionable.
String _truncate(String reason) {
  if (reason.length <= kMaxExtractedErrorLength) return reason;
  return '${reason.substring(0, kMaxExtractedErrorLength - 1)}…';
}

/// Walks the provider error body looking for a human-readable reason.
String? _extractReason(Object? data) {
  if (data == null) return null;

  if (data is String) {
    final trimmed = data.trim();
    if (trimmed.isEmpty) return null;
    // Some gateways return the JSON error as a string body.
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        final fromJson = _extractReason(decoded);
        if (fromJson != null) return fromJson;
      } on FormatException {
        // Not actually JSON — fall through and treat it as text.
      }
    }
    return _stripHtml(trimmed);
  }

  if (data is Map) {
    // Ordered by how specific each key is, most specific first.
    for (final key in const [
      'error.message',
      'error.metadata.raw',
      'error.detail',
      'message',
      'detail',
      'error',
    ]) {
      final value = _dig(data, key);
      if (value == null) continue;
      final text = _asText(value);
      if (text != null && text.isNotEmpty) return text;
    }
    // Last resort: serialize the whole body so nothing is silently lost.
    try {
      return jsonEncode(data);
    } on Object {
      return data.toString();
    }
  }

  if (data is List) {
    final parts = <String>[];
    for (final item in data) {
      final text = _extractReason(item);
      if (text != null && text.isNotEmpty) parts.add(text);
    }
    if (parts.isEmpty) return null;
    return parts.join('; ');
  }

  return data.toString();
}

/// Reads a dot-separated path out of a nested map.
Object? _dig(Map<dynamic, dynamic> map, String path) {
  Object? current = map;
  for (final key in path.split('.')) {
    if (current is! Map) return null;
    current = current[key];
  }
  return current;
}

/// Coerces an arbitrary JSON value into text.
String? _asText(Object? value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  if (value is Map || value is List) {
    // A nested object is usually a structured detail block; recurse so we
    // prefer its `message` field over a raw serialization.
    final nested = _extractReason(value);
    if (nested != null) return nested;
  }
  return null;
}

/// Strips tags and collapses whitespace so an HTML error page stays readable.
String _stripHtml(String input) {
  final withoutTags = input.replaceAll(RegExp(r'<[^>]*>'), ' ');
  final collapsed = withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.isEmpty ? input : collapsed;
}

/// Cleans `DioException.message`, which is mostly boilerplate about
/// `validateStatus` rather than anything about the request.
String? _cleanFallback(String? message) {
  if (message == null) return null;
  final trimmed = message.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.length <= kMaxExtractedErrorLength) return trimmed;
  return '${trimmed.substring(0, kMaxExtractedErrorLength)}…';
}
