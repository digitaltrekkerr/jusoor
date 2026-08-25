import 'dart:convert';

import '../exceptions/translation_exception.dart';

/// Extracts a value from a JSON map using a dot-notation path.
///
/// Path segments separated by `.` navigate into nested maps. If a segment is
/// a valid integer it is treated as a list index; otherwise it is treated as
/// a map key.
///
/// Example:
/// ```dart
/// final json = {'choices': [{'message': {'content': 'Hello'}}]};
/// final value = ResponsePathExtractor.extract(json, 'choices.0.message.content');
/// // value == 'Hello'
/// ```
class ResponsePathExtractor {
  ResponsePathExtractor._();

  /// Extracts the value at [path] from [json] and returns it as a [String].
  ///
  /// Throws [ResponsePathException] if the path cannot be fully resolved.
  static String extract(Map<String, dynamic> json, String path) {
    final segments = path.split('.');
    dynamic current = json;

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final index = int.tryParse(segment);

      if (index != null) {
        if (current is List) {
          if (index < 0 || index >= current.length) {
            throw ResponsePathException(
              'Index $index out of range for list of length ${current.length}',
              path,
            );
          }
          current = current[index];
        } else {
          throw ResponsePathException(
            'Expected a list at segment "$segment" but found ${current.runtimeType}',
            path,
          );
        }
      } else {
        if (current is Map<String, dynamic>) {
          if (!current.containsKey(segment)) {
            throw ResponsePathException(
              'Key "$segment" not found in map',
              path,
            );
          }
          current = current[segment];
        } else if (current is Map) {
          if (!current.containsKey(segment)) {
            throw ResponsePathException(
              'Key "$segment" not found in map',
              path,
            );
          }
          current = current[segment];
        } else {
          throw ResponsePathException(
            'Expected a map at segment "$segment" but found ${current.runtimeType}',
            path,
          );
        }
      }
    }

    if (current == null) {
      throw ResponsePathException('Value at path is null', path);
    }

    if (current is String) {
      return current;
    } else if (current is List) {
      return current.join('');
    } else if (current is Map) {
      return jsonEncode(current);
    }
    return current.toString();
  }
}
