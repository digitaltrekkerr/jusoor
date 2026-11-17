import 'package:dio/dio.dart';

import 'model_capabilities.dart';
import 'translation_request.dart';

/// Abstract interface for a translation backend.
///
/// Implementations must provide a [translate] method that returns a [Stream]
/// of partial translation chunks, enabling real-time streaming output.
abstract class TranslationProvider {
  /// Translates [request] and yields partial text chunks as they arrive.
  ///
  /// The stream completes when the full translation is received. Errors are
  /// surfaced as [TranslationException] or [ResponsePathException]. When the
  /// user cancels via [cancelToken], the underlying HTTP call is aborted and
  /// the stream ends with a [TranslationCancelledException] (never a
  /// [TranslationException] fallback).
  Stream<String> translate(
    TranslationRequest request, {
    CancelToken? cancelToken,
  });
  
  /// Fetches a list of available model identifiers from the provider.
  Future<List<String>> fetchModels();

  /// Fetches the reasoning capabilities of the provider's models.
  ///
  /// Providers that cannot report this return an empty list, which callers
  /// must treat as "capabilities unknown" — never as "no model supports
  /// reasoning". The distinction matters because an unknown capability set
  /// makes [ModelCapabilities.sanitize] omit the `reasoning` key entirely,
  /// which is the safe default: sending reasoning to a model that does not
  /// support it is rejected with a 400.
  ///
  /// Only [OpenRouterProvider] implements this today.
  Future<List<ModelCapabilities>> fetchModelCapabilities() async => const [];
}
