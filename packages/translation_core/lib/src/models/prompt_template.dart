import 'package:equatable/equatable.dart';

/// A reusable prompt template tied to a [ProviderProfile].
///
/// Templates define the system prompt and capabilities (text and/or image
/// translation). Built-in templates are read-only and cannot be deleted.
class PromptTemplate extends Equatable {
  /// Unique identifier (UUID).
  final String id;

  /// ID of the [ProviderProfile] this template belongs to.
  final String profileId;

  /// Display name, e.g. "Professional Translator", "Image Translator".
  final String name;

  /// System prompt text with `{{target_language}}` and other placeholders.
  final String systemPrompt;

  /// Whether this template can be used for text translation.
  final bool supportsText;

  /// Whether this template can be used for image/vision translation.
  final bool supportsImage;

  /// Whether this is a pre-built template (not editable, not deletable).
  final bool isBuiltIn;

  /// Whether `{{target_language}}` in [systemPrompt] is replaced with the
  /// actual language name before being sent to the LLM.
  ///
  /// When `true` (the default), the placeholder is substituted with the
  /// chosen target language (e.g. `{{target_language}}` → `"Arabic"`).
  /// When `false`, the literal placeholder `{{target_language}}` is left
  /// in the prompt so the LLM sees it verbatim — useful for models or
  /// provider pipelines that handle language selection themselves.
  ///
  /// Defaults to `true` for backward compatibility.
  final bool substituteTargetLanguage;

  /// Creates a [PromptTemplate].
  const PromptTemplate({
    required this.id,
    required this.profileId,
    required this.name,
    required this.systemPrompt,
    required this.supportsText,
    required this.supportsImage,
    this.isBuiltIn = false,
    this.substituteTargetLanguage = true,
  });

  /// Creates a [PromptTemplate] from a JSON map.
  ///
  /// Missing or null keys are handled gracefully — nullable fields default to
  /// sensible values.
  factory PromptTemplate.fromJson(Map<String, dynamic> json) {
    return PromptTemplate(
      id: json['id'] as String? ?? '',
      profileId: json['profileId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      supportsText: json['supportsText'] as bool? ?? true,
      supportsImage: json['supportsImage'] as bool? ?? false,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      substituteTargetLanguage:
          json['substituteTargetLanguage'] as bool? ?? true,
    );
  }

  /// Converts this [PromptTemplate] to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'name': name,
      'systemPrompt': systemPrompt,
      'supportsText': supportsText,
      'supportsImage': supportsImage,
      'isBuiltIn': isBuiltIn,
      'substituteTargetLanguage': substituteTargetLanguage,
    };
  }

  /// Creates a copy of this template with the given fields replaced.
  PromptTemplate copyWith({
    String? id,
    String? profileId,
    String? name,
    String? systemPrompt,
    bool? supportsText,
    bool? supportsImage,
    bool? isBuiltIn,
    bool? substituteTargetLanguage,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      supportsText: supportsText ?? this.supportsText,
      supportsImage: supportsImage ?? this.supportsImage,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      substituteTargetLanguage:
          substituteTargetLanguage ?? this.substituteTargetLanguage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    profileId,
    name,
    systemPrompt,
    supportsText,
    supportsImage,
    isBuiltIn,
    substituteTargetLanguage,
  ];
}
