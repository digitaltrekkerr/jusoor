/// Supported translation provider backends.
enum ProviderType {
  /// OpenAI-compatible REST API (Ollama, LM Studio, vLLM, etc.).
  openaiCompatible,

  /// Google Gemini API.
  gemini,

  /// OpenRouter API.
  openrouter;

  /// Creates a [ProviderType] from its JSON string representation.
  ///
  /// Throws [ArgumentError] if [value] does not match any known provider type.
  factory ProviderType.fromJson(String value) {
    switch (value) {
      case 'openai_compatible':
        return ProviderType.openaiCompatible;
      case 'gemini':
        return ProviderType.gemini;
      case 'openrouter':
        return ProviderType.openrouter;
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unknown ProviderType JSON value',
        );
    }
  }

  /// Converts this [ProviderType] to its JSON string representation.
  String toJson() {
    switch (this) {
      case ProviderType.openaiCompatible:
        return 'openai_compatible';
      case ProviderType.gemini:
        return 'gemini';
      case ProviderType.openrouter:
        return 'openrouter';
    }
  }

  /// Human-readable display name for this provider type.
  String get displayName {
    switch (this) {
      case ProviderType.openaiCompatible:
        return 'OpenAI-Compatible';
      case ProviderType.gemini:
        return 'Gemini';
      case ProviderType.openrouter:
        return 'OpenRouter';
    }
  }
}
