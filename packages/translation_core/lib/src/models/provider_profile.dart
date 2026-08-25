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
  ];
}
