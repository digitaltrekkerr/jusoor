import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../exceptions/translation_exception.dart';
import 'response_path_extractor.dart';

/// Parses Server-Sent Events (SSE) data chunks and yields extracted content
/// strings.
///
/// Handles both `data: ` (with space) and `data:` (without space) prefixes,
/// the `[DONE]` termination signal, and buffers incomplete lines across chunks.
/// Content is extracted from each parsed JSON event using
/// [ResponsePathExtractor] with the configured [responsePath].
class SSEParser {
  /// Buffer for incomplete lines that span chunk boundaries.
  final StringBuffer _buffer = StringBuffer();

  /// Dot-notation path used to extract content from each SSE JSON payload.
  final String responsePath;

  /// Creates an [SSEParser] that extracts content from each event using
  /// [responsePath].
  ///
  /// Defaults to `choices.0.delta.content` which is the standard OpenAI
  /// streaming delta path.
  SSEParser({this.responsePath = 'choices.0.delta.content'});

  /// Parses a raw SSE [chunk] and returns a list of extracted content
  /// strings.
  ///
  /// Incomplete lines are buffered until a newline arrives in a subsequent
  /// chunk. The `[DONE]` signal is recognised and does not produce output.
  List<String> parseChunk(String chunk) {
    _buffer.write(chunk);
    final results = <String>[];

    final data = _buffer.toString();
    final lines = data.split('\n');

    // The last element may be an incomplete line — keep it in the buffer.
    _buffer.clear();
    _buffer.write(lines.last);

    for (var i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      String? payload;
      if (line.startsWith('data: ')) {
        payload = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        payload = line.substring(5).trim();
      } else {
        continue;
      }

      if (payload == '[DONE]') continue;

      try {
        final json = jsonDecode(payload) as Map<String, dynamic>;
        final content = ResponsePathExtractor.extract(json, responsePath);
        if (content.isNotEmpty) {
          results.add(content);
        }
      } on FormatException catch (e) {
        // Malformed JSON — log and skip this event.
        debugPrint('SSE: malformed JSON skipped — $e');
      } on ResponsePathException catch (e) {
        // Path not found in this event (e.g. role-only delta) — log and skip.
        debugPrint('SSE: response path not found — $e');
      }
    }

    return results;
  }

  /// Resets the internal buffer.
  ///
  /// Call this between independent SSE streams.
  void reset() {
    _buffer.clear();
  }
}
