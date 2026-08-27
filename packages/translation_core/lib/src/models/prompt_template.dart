// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'package:equatable/equatable.dart';

/// A named prompt template that pairs a [ProviderProfile] with a
/// system prompt and capability flags.
///
/// Templates are the user-editable unit behind the home screen's
/// text/image template selector and the translation overlay. They are
/// persisted to disk via [toJson]/[fromJson] and round-tripped through
/// shared preferences (no schema migration is performed — unknown
/// fields on read are simply ignored).
class PromptTemplate extends Equatable {
  /// Stable identifier; the SQLite primary key for user templates and a
  /// fixed constant for built-in templates.
  final String id;

  /// Identifier of the [ProviderProfile] used to translate this template.
  final String profileId;

  /// Human-readable name shown in the template selector and editor.
  final String name;

  /// System prompt body. May contain `{{target_language}}` and
  /// `{{source_language}}` placeholders that the substitution layer
  /// fills before the request is sent.
  final String systemPrompt;

  /// Whether this template is offered for text input. Templates that
  /// only handle images leave this `false` to hide them in the text
  /// selector.
  final bool supportsText;

  /// Whether this template accepts an image (multimodal) input.
  final bool supportsImage;

  /// Marks a template shipped with the app. Built-in templates cannot
  /// be deleted and are restored to their shipped prompt on reset.
  final bool isBuiltIn;

  /// When `true` (the default), the substitution layer replaces
  /// `{{target_language}}` in [systemPrompt] with the user-selected
  /// target language before sending. When `false`, the placeholder is
  /// preserved verbatim in the prompt — useful for profiles whose
  /// provider pipeline handles language selection itself.
  final bool substituteTargetLanguage;

  /// When `true`, this template does not depend on a `{{target_language}}`
  /// variable — its output language is fixed inside the template body.
  ///
  /// The home screen hides the target-language selector when this template
  /// is active, and the overlay translation feature refuses to use it
  /// (the overlay always needs a user-chosen target language).
  ///
  /// Defaults to `false` for backward compatibility.
  final bool outputLanguageFixed;

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
    this.outputLanguageFixed = false,
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
      outputLanguageFixed: json['outputLanguageFixed'] as bool? ?? false,
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
      'outputLanguageFixed': outputLanguageFixed,
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
    bool? outputLanguageFixed,
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
      outputLanguageFixed: outputLanguageFixed ?? this.outputLanguageFixed,
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
    outputLanguageFixed,
  ];
}
