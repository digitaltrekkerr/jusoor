import '../models/translation_request.dart';

/// Substitutes `{{variable}}` placeholders in template strings with values
/// derived from a [TranslationRequest].
///
/// Supported variables:
/// - `system_prompt`
/// - `input_text`
/// - `target_language`
/// - `source_language`
/// - `image_base64`
/// - `image_mime_type`
/// - `api_key`
/// - `model`
/// - `word_count`
///
/// Unknown variables are replaced with an empty string.
///
/// ### `{{target_language}}` opt-out
///
/// When the [substituteTargetLanguage] flag is `false`, the literal
/// `{{target_language}}` placeholder is preserved in the output and is
/// NOT replaced with the actual target language name. All other
/// placeholders (e.g. `{{source_text}}`, `{{model}}`) continue to be
/// substituted as usual. This is useful for models or provider pipelines
/// that handle language selection themselves.
///
/// ### Nested placeholder resolution
///
/// [substitute] and [substituteMap] run **multiple passes** so that
/// placeholders inside replaced values are also resolved. For example,
/// if `{{system_prompt}}` expands to `"Translate to {{target_language}}"`,
/// the inner `{{target_language}}` is resolved on the next pass.
///
/// A maximum of 5 passes prevents infinite loops from circular references.
///
/// ### `{{target_language}}` safety net
///
/// A literal `'auto'` / `'تلقائي'` (case-insensitive) or an empty value can
/// never be substituted for `{{target_language}}` — any such value falls
/// back to [_fallbackTargetLanguage] (`'Arabic'`).
/// Without this guard a prompt such as "translate to auto" makes the model
/// return the source text unchanged.
class VariableSubstitutor {
  VariableSubstitutor._();

  /// Regular expression matching `{{variable}}` placeholders.
  static final RegExp _placeholderPattern = RegExp(r'\{\{(\w+)\}\}');

  /// Maximum number of substitution passes to prevent infinite loops
  /// caused by circular placeholder references.
  static const int _maxPasses = 5;

  /// Fallback value substituted for `{{target_language}}` when a caller
  /// supplies the `'auto'` sentinel (English or Arabic, case-insensitive)
  /// or an empty string. Matches the app-level persisted default target
  /// language (the translation_app settings repository defaults to
  /// `'Arabic'`).
  static const String _fallbackTargetLanguage = 'Arabic';

  /// Substitutes all `{{variable}}` placeholders in [template] using values
  /// from [request].
  ///
  /// **Note:** This method does NOT inject the `{{api_key}}` variable.
  /// Use [buildVariableMap] + [substituteMap] instead when API key
  /// substitution is required.
  ///
  /// The [request]'s [TranslationRequest.substituteTargetLanguage] flag
  /// controls whether `{{target_language}}` is replaced or left literal.
  ///
  /// Runs multiple passes so that nested placeholders (e.g.
  /// `{{target_language}}` inside a resolved `{{system_prompt}}`) are
  /// also expanded.
  ///
  /// If a placeholder name is not recognized it is replaced with an empty
  /// string.
  static String substitute(
    String template,
    TranslationRequest request,
  ) {
    final variables = _buildVariableMap(request);
    return _multiPassSubstitute(
      template,
      variables,
      skipPlaceholders: request.substituteTargetLanguage
          ? const <String>{}
          : const <String>{'target_language'},
    );
  }

  /// Substitutes placeholders in [template] using an explicit [variables] map.
  ///
  /// When [substituteTargetLanguage] is `false`, the literal
  /// `{{target_language}}` placeholder is preserved in the output instead
  /// of being replaced from the map (or an empty string if missing).
  ///
  /// Runs multiple passes so that nested placeholders are resolved.
  ///
  /// This is useful for substituting headers or other non-body templates where
  /// the values come from a caller-supplied map rather than a
  /// [TranslationRequest].
  static String substituteMap(
    String template,
    Map<String, String> variables, {
    bool substituteTargetLanguage = true,
  }) {
    return _multiPassSubstitute(
      template,
      variables,
      skipPlaceholders: substituteTargetLanguage
          ? const <String>{}
          : const <String>{'target_language'},
    );
  }

  /// Performs multi-pass substitution until no more placeholders are found
  /// or [_maxPasses] is reached.
  ///
  /// This ensures that placeholders inside resolved values are also expanded.
  /// For example, if `{{system_prompt}}` resolves to
  /// `"Translate to {{target_language}}"`, the inner placeholder is
  /// resolved on the next pass.
  ///
  /// Placeholders whose name appears in [skipPlaceholders] are left
  /// untouched in every pass — their original `{{name}}` form is preserved
  /// in the output. This is how `{{target_language}}` is kept literal
  /// when the caller opts out of target-language substitution.
  static String _multiPassSubstitute(
    String template,
    Map<String, String> variables, {
    Set<String> skipPlaceholders = const <String>{},
  }) {
    var result = template;
    for (var i = 0; i < _maxPasses; i++) {
      final next = result.replaceAllMapped(_placeholderPattern, (match) {
        final key = match.group(1);
        if (key == null) return '';
        if (skipPlaceholders.contains(key)) {
          // Preserve the original `{{name}}` token literally.
          return match.group(0)!;
        }
        if (key == 'target_language') {
          // Safety net applied at the substitution choke point as well as in
          // the variable maps: never let the 'auto' sentinel (English or
          // Arabic, case-insensitive) or an empty value reach the prompt —
          // "translate to auto" makes the model echo the source unchanged.
          return _safeTargetLanguage(variables[key] ?? '');
        }
        return variables[key] ?? '';
      });
      if (next == result) break; // No more placeholders resolved.
      result = next;
    }
    return result;
  }

  /// Returns a safe value for the `{{target_language}}` placeholder.
  ///
  /// Safety net: a literal `'auto'` or `'تلقائي'` (case-insensitive, after
  /// trimming) or an empty value must never be emitted into a prompt.
  /// Callers that have not resolved a concrete language fall back to
  /// [_fallbackTargetLanguage] instead of the sentinel.
  static String _safeTargetLanguage(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return _fallbackTargetLanguage;
    final lower = trimmed.toLowerCase();
    if (lower == 'auto' || lower == 'تلقائي') return _fallbackTargetLanguage;
    return value;
  }

  /// Escapes a string value for safe embedding inside a JSON string literal.
  ///
  /// This must be applied to user-supplied values before they are substituted
  /// into JSON body templates to prevent [FormatException] errors caused by
  /// control characters (newlines, tabs, etc.) or unescaped quotes and
  /// backslashes.
  ///
  /// Follows the JSON string escaping rules from RFC 8259 §7:
  /// - `\` → `\\`
  /// - `"` → `\"`
  /// - newline → `\n`
  /// - carriage return → `\r`
  /// - tab → `\t`
  /// - backspace → `\b`
  /// - form feed → `\f`
  /// - Other control characters (U+0000 – U+001F) → `\uXXXX`
  static String jsonEscape(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.runes) {
      switch (codeUnit) {
        case 0x08: // backspace
          buffer.write('\\b');
        case 0x09: // tab
          buffer.write('\\t');
        case 0x0A: // newline
          buffer.write('\\n');
        case 0x0C: // form feed
          buffer.write('\\f');
        case 0x0D: // carriage return
          buffer.write('\\r');
        case 0x22: // double quote
          buffer.write('\\"');
        case 0x5C: // backslash
          buffer.write('\\\\');
        default:
          if (codeUnit < 0x20) {
            // Other control characters → \uXXXX
            buffer.write(
              '\\u${codeUnit.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            );
          } else {
            buffer.writeCharCode(codeUnit);
          }
      }
    }
    return buffer.toString();
  }

  /// Builds the canonical variable map from a [TranslationRequest].
  ///
  /// User-facing string values ([inputText], [systemPrompt],
  /// [targetLanguage]) are JSON-escaped to prevent
  /// [FormatException] when they are substituted into JSON body templates.
  static Map<String, String> _buildVariableMap(TranslationRequest request) {
    return {
      'system_prompt': jsonEscape(request.systemPrompt),
      'input_text': jsonEscape(request.inputText),
      'target_language': jsonEscape(_safeTargetLanguage(request.targetLanguage)),
      'image_base64': request.imageBase64 ?? '',
      'image_mime_type': request.imageMimeType ?? 'image/jpeg',
      'api_key':
          '', // Not available via substitute(); use buildVariableMap() instead
      'model': request.model,
      'word_count': request.wordCount.toString(),
    };
  }

  /// Builds a variable map from a [TranslationRequest] plus an [apiKey]
  /// override.
  ///
  /// This is the preferred entry point for providers that need to inject the
  /// API key into templates.
  ///
  /// User-facing string values are JSON-escaped to prevent [FormatException].
  static Map<String, String> buildVariableMap(
    TranslationRequest request,
    String apiKey,
  ) {
    return {
      'system_prompt': jsonEscape(request.systemPrompt),
      'input_text': jsonEscape(request.inputText),
      'target_language': jsonEscape(_safeTargetLanguage(request.targetLanguage)),
      'image_base64': request.imageBase64 ?? '',
      'image_mime_type': request.imageMimeType ?? 'image/jpeg',
      'api_key': jsonEscape(apiKey),
      'model': request.model,
      'word_count': request.wordCount.toString(),
    };
  }

  /// Builds a variable map **without** JSON-escaping string values.
  ///
  /// Use this when substituting into a non-JSON context (e.g. a Dart string
  /// that will be placed into a programmatic Map, not into a raw JSON
  /// template). This avoids double-escaping issues where [jsonEscape] would
  /// turn newlines into literal `\n` character pairs.
  ///
  /// If [apiKey] is provided, it is included as `api_key` (also unescaped).
  static Map<String, String> buildRawVariableMap(
    TranslationRequest request, [
    String? apiKey,
  ]) {
    return {
      'system_prompt': request.systemPrompt,
      'input_text': request.inputText,
      'target_language': _safeTargetLanguage(request.targetLanguage),
      'image_base64': request.imageBase64 ?? '',
      'image_mime_type': request.imageMimeType ?? 'image/jpeg',
      'api_key': apiKey ?? '',
      'model': request.model,
      'word_count': request.wordCount.toString(),
    };
  }
}
