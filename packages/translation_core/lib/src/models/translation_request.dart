// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'package:equatable/equatable.dart';

/// A translation request carrying all the information needed to ask a
/// translation provider for a translation.
class TranslationRequest extends Equatable {
  /// The source text to translate.
  final String inputText;

  /// The ISO language code (or name) to translate into.
  final String targetLanguage;

  /// Optional base-64 encoded image for multimodal translation requests.
  ///
  /// When `null`, the `{{image_base64}}` template variable resolves to an
  /// empty string.
  final String? imageBase64;

  /// MIME type of the image in [imageBase64], e.g. `image/png` or
  /// `image/webp`.
  ///
  /// Defaults to `image/jpeg` when [imageBase64] is set but this field is
  /// `null`.
  final String? imageMimeType;

  /// Number of words in [inputText].
  ///
  /// Used by the `{{word_count}}` template variable. Defaults to `0` if not
  /// explicitly set.
  final int wordCount;

  /// System prompt that instructs the model how to behave.
  ///
  /// Defaults to `'You are a professional translator.'`.
  final String systemPrompt;

  /// The model identifier to use (e.g. `'openai/gpt-4o'`).
  ///
  /// Defaults to `'openai/gpt-4o'`.
  final String model;

  /// Optional identifier of the [ProviderProfile] used for this request.
  ///
  /// When set, tracks which profile's configuration was applied.
  final String? profileId;

  /// Whether `{{target_language}}` in [systemPrompt] should be substituted
  /// with [targetLanguage] before the prompt is sent to the LLM.
  ///
  /// When `true` (the default), the placeholder is replaced with the
  /// target language name. When `false`, the literal `{{target_language}}`
  /// is preserved in the prompt — useful when the underlying model or
  /// provider pipeline handles language selection itself.
  ///
  /// This flag is propagated from the originating [PromptTemplate] and
  /// exists here so that the substitution layer inside the providers can
  /// honor it without needing direct access to the template object.
  final bool substituteTargetLanguage;

  /// Creates a [TranslationRequest].
  ///
  /// Only [inputText] and [targetLanguage] are required; all other fields
  /// have sensible defaults.
  const TranslationRequest({
    required this.inputText,
    required this.targetLanguage,
    this.imageBase64,
    this.imageMimeType,
    this.wordCount = 0,
    this.systemPrompt = 'You are a professional translator.',
    this.model = 'openai/gpt-4o',
    this.profileId,
    this.substituteTargetLanguage = true,
  }) : assert(
         inputText != '' || imageBase64 != null,
         'inputText must not be empty unless imageBase64 is provided',
       ),
       assert(targetLanguage != '', 'targetLanguage must not be empty');

  /// Creates a [TranslationRequest] from a JSON map.
  factory TranslationRequest.fromJson(Map<String, dynamic> json) {
    return TranslationRequest(
      inputText: json['inputText'] as String? ?? '',
      targetLanguage: json['targetLanguage'] as String? ?? '',
      imageBase64: json['imageBase64'] as String?,
      imageMimeType: json['imageMimeType'] as String?,
      wordCount: json['wordCount'] as int? ?? 0,
      systemPrompt: json['systemPrompt'] as String? ??
          'You are a professional translator.',
      model: json['model'] as String? ?? 'openai/gpt-4o',
      profileId: json['profileId'] as String?,
      substituteTargetLanguage:
          json['substituteTargetLanguage'] as bool? ?? true,
    );
  }

  /// Converts this [TranslationRequest] to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'inputText': inputText,
      'targetLanguage': targetLanguage,
      'imageBase64': imageBase64,
      'imageMimeType': imageMimeType,
      'wordCount': wordCount,
      'systemPrompt': systemPrompt,
      'model': model,
      'profileId': profileId,
      'substituteTargetLanguage': substituteTargetLanguage,
    };
  }

  /// Returns a copy of this request with the given fields replaced.
  ///
  /// Nullable fields use an undefined sentinel so callers can explicitly
  /// pass `null` to clear them without the `??` fallback swallowing the
  /// intent.
  TranslationRequest copyWith({
    String? inputText,
    String? targetLanguage,
    Object? imageBase64 = _undefined,
    Object? imageMimeType = _undefined,
    int? wordCount,
    String? systemPrompt,
    String? model,
    Object? profileId = _undefined,
    bool? substituteTargetLanguage,
  }) {
    return TranslationRequest(
      inputText: inputText ?? this.inputText,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      imageBase64: identical(imageBase64, _undefined)
          ? this.imageBase64
          : imageBase64 as String?,
      imageMimeType: identical(imageMimeType, _undefined)
          ? this.imageMimeType
          : imageMimeType as String?,
      wordCount: wordCount ?? this.wordCount,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      model: model ?? this.model,
      profileId: identical(profileId, _undefined)
          ? this.profileId
          : profileId as String?,
      substituteTargetLanguage:
          substituteTargetLanguage ?? this.substituteTargetLanguage,
    );
  }

  @override
  List<Object?> get props => [
        inputText,
        targetLanguage,
        imageBase64,
        imageMimeType,
        wordCount,
        systemPrompt,
        model,
        profileId,
        substituteTargetLanguage,
      ];
}

/// Sentinel object used by [TranslationRequest.copyWith] to distinguish
/// "argument omitted" from "argument explicitly passed as null".
const Object _undefined = Object();
