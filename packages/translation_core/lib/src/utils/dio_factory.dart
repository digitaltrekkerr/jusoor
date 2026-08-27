import 'package:dio/dio.dart';

/// Creates a [Dio] instance configured with timeout defaults for
/// translation API calls. Per-call overrides are supported via each
/// provider's optional [Dio] constructor parameter.
///
/// Timeouts:
///   * [BaseOptions.connectTimeout] = 10 seconds — fail fast on
///     unreachable or black-holed endpoints.
///   * [BaseOptions.receiveTimeout] = 120 seconds — streaming
///     translations of long documents may take longer than the
///     default 30 s.
///   * [BaseOptions.sendTimeout] = 30 seconds — request bodies are
///     small JSON; 30 s is generous.
Dio createTranslationDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
    ),
  );
}
