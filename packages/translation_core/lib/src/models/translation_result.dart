import 'package:equatable/equatable.dart';

/// The result of a completed translation request.
class TranslationResult extends Equatable {
  /// The translated text returned by the provider.
  final String outputText;

  /// The model that was actually used for the translation.
  final String modelUsed;

  /// Wall-clock duration of the translation in milliseconds.
  final int durationMs;

  /// Creates a [TranslationResult].
  const TranslationResult({
    required this.outputText,
    required this.modelUsed,
    required this.durationMs,
  });

  @override
  List<Object?> get props => [outputText, modelUsed, durationMs];
}
