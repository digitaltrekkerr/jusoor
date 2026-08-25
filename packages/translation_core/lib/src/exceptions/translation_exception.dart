/// Exception thrown when a translation request fails.
///
/// Contains a human-readable [message] and an optional HTTP [statusCode]
/// when the failure originated from an HTTP response.
class TranslationException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// Optional HTTP status code associated with the failure.
  final int? statusCode;

  /// Creates a [TranslationException] with [message] and optional [statusCode].
  const TranslationException(this.message, {this.statusCode});

  @override
  String toString() =>
      'TranslationException: $message${statusCode != null ? ' (status: $statusCode)' : ''}';
}

/// Exception thrown when a response path cannot be resolved in JSON data.
///
/// Contains the [message] describing why extraction failed and the [path]
/// that was attempted.
class ResponsePathException implements Exception {
  /// Human-readable description of the failure.
  final String message;

  /// The dot-notation path that could not be resolved.
  final String path;

  /// Creates a [ResponsePathException] with [message] and the unresolved [path].
  const ResponsePathException(this.message, this.path);

  @override
  String toString() => 'ResponsePathException: $message (path: $path)';
}
