import 'translation_request.dart';

/// Abstract interface for a translation backend.
///
/// Implementations must provide a [translate] method that returns a [Stream]
/// of partial translation chunks, enabling real-time streaming output.
abstract class TranslationProvider {
  /// Translates [request] and yields partial text chunks as they arrive.
  ///
  /// The stream completes when the full translation is received. Errors are
  /// surfaced as [TranslationException] or [ResponsePathException].
  Stream<String> translate(TranslationRequest request);
  
  /// Fetches a list of available model identifiers from the provider.
  Future<List<String>> fetchModels();
}
