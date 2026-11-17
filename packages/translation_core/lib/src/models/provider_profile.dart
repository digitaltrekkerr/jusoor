import 'package:equatable/equatable.dart';

import 'provider_type.dart';

const _undefined = Object();

class ProviderProfile extends Equatable {
  final String id;

  final String name;

  final ProviderType providerType;

  final String? apiKeyId;

  final String? fallbackApiKeyId;

  final String model;

  final String? visionModel;

  final String? baseUrl;

  final bool isBuiltIn;

  /// Reasoning effort requested for this profile's models.
  ///
  /// Persisted as the provider wire value (`"low"`, `"medium"`, …) rather
  /// than the Dart enum name, so a profile saved by a future version that
  /// adds new levels still parses without a migration.
  ///
  /// `null` means the profile expresses no preference, which keeps requests
  /// byte-identical to what older versions produced.
  ///
  /// Only honoured by [ProviderType.openrouter] profiles; other providers
  /// ignore it and never emit a `reasoning` block.
  final String? reasoningEffort;

  /// Whether reasoning tokens are withheld from the response.
  ///
  /// Defaults to `true` — raw chain-of-thought would otherwise stream into
  /// the translation overlay. The tokens are consumed and billed regardless.
  final bool reasoningExclude;

  const ProviderProfile({
    required this.id,
    required this.name,
    required this.providerType,
    this.apiKeyId,
    this.fallbackApiKeyId,
    required this.model,
    this.visionModel,
    this.baseUrl,
    this.isBuiltIn = false,
    this.reasoningEffort,
    this.reasoningExclude = true,
  });

  factory ProviderProfile.fromJson(Map<String, dynamic> json) {
    return ProviderProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      providerType: json['providerType'] != null
          ? ProviderType.fromJson(json['providerType'] as String)
          : ProviderType.openrouter,
      apiKeyId: json['apiKeyId'] as String?,
      fallbackApiKeyId: json['fallbackApiKeyId'] as String?,
      model: json['model'] as String? ?? '',
      visionModel: json['visionModel'] as String?,
      baseUrl: json['baseUrl'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      reasoningEffort: json['reasoningEffort'] as String?,
      reasoningExclude: json['reasoningExclude'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'providerType': providerType.toJson(),
      'apiKeyId': apiKeyId,
      'fallbackApiKeyId': fallbackApiKeyId,
      'model': model,
      'visionModel': visionModel,
      'baseUrl': baseUrl,
      'isBuiltIn': isBuiltIn,
      'reasoningEffort': reasoningEffort,
      'reasoningExclude': reasoningExclude,
    };
  }

  ProviderProfile copyWith({
    String? id,
    String? name,
    ProviderType? providerType,
    Object? apiKeyId = _undefined,
    Object? fallbackApiKeyId = _undefined,
    String? model,
    String? visionModel,
    String? baseUrl,
    bool? isBuiltIn,
    Object? reasoningEffort = _undefined,
    bool? reasoningExclude,
  }) {
    return ProviderProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      apiKeyId: identical(apiKeyId, _undefined)
          ? this.apiKeyId
          : apiKeyId as String?,
      fallbackApiKeyId: identical(fallbackApiKeyId, _undefined)
          ? this.fallbackApiKeyId
          : fallbackApiKeyId as String?,
      model: model ?? this.model,
      visionModel: visionModel ?? this.visionModel,
      baseUrl: baseUrl ?? this.baseUrl,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      reasoningEffort: identical(reasoningEffort, _undefined)
          ? this.reasoningEffort
          : reasoningEffort as String?,
      reasoningExclude: reasoningExclude ?? this.reasoningExclude,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    providerType,
    apiKeyId,
    fallbackApiKeyId,
    model,
    visionModel,
    baseUrl,
    isBuiltIn,
    reasoningEffort,
    reasoningExclude,
  ];
}
