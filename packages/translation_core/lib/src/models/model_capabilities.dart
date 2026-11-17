// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

import 'reasoning_effort.dart';

/// Describes which reasoning options a single model accepts.
///
/// Reported by [OpenRouterProvider.fetchModelCapabilities] and used to gate
/// the effort selector in the settings UI and to clamp the value that ends
/// up on the wire.
///
/// The reason this exists at all: OpenRouter **rejects a request with a 400**
/// when it carries an effort the selected model does not support. Sending
/// `reasoning` to a model that has no reasoning support, or `effort: "none"`
/// to a model where reasoning is mandatory, produces exactly that failure.
/// Every path that writes a `reasoning` block therefore goes through
/// [sanitize] first.
class ModelCapabilities {
  /// The model identifier these capabilities belong to.
  final String id;

  /// Whether the provider actually reported capabilities for this model.
  ///
  /// When `false` nothing is known — the provider was unreachable, or the
  /// model was absent from the listing. Sanitization then **passes the
  /// user's choice through untouched** rather than silently discarding it:
  /// someone who picked an effort in settings should get what they asked
  /// for, and a 400 from an unexpected combination is now legible thanks to
  /// [describeDioError] instead of being a mystery.
  final bool known;

  /// Whether the model exposes reasoning at all.
  ///
  /// Non-reasoning models and dynamic router models (`openrouter/auto`,
  /// `openrouter/free`) report `false`.
  final bool supportsReasoning;

  /// Whether reasoning cannot be turned off for this model.
  ///
  /// When `true` the UI must hide the "off" control and [sanitize] must
  /// never return [ReasoningEffort.none].
  final bool reasoningMandatory;

  /// The efforts the model accepts, in descending order (strongest first),
  /// as reported by the provider.
  final List<ReasoningEffort> supportedEfforts;

  /// The effort the provider uses when the user has not expressed a
  /// preference. `null` when the provider does not report one.
  final ReasoningEffort? defaultEffort;

  /// Whether reasoning is on by default for this model.
  final bool defaultEnabled;

  /// Creates a [ModelCapabilities] record.
  const ModelCapabilities({
    required this.id,
    this.known = false,
    this.supportsReasoning = false,
    this.reasoningMandatory = false,
    this.supportedEfforts = const [],
    this.defaultEffort,
    this.defaultEnabled = false,
  });

  /// Capabilities for a model about which nothing is known.
  const ModelCapabilities.unknown(this.id)
      : known = false,
        supportsReasoning = false,
        reasoningMandatory = false,
        supportedEfforts = const [],
        defaultEffort = null,
        defaultEnabled = false;

  /// Whether [effort] may be sent to this model as-is.
  ///
  /// Always `true` when capabilities are unknown, since there is nothing to
  /// check against.
  bool canSend(ReasoningEffort effort) {
    if (!known) return true;
    if (effort == ReasoningEffort.none) {
      return supportsReasoning && !reasoningMandatory;
    }
    return supportedEfforts.contains(effort);
  }

  /// Resolves [requested] into the closest effort this model accepts.
  ///
  /// Returns [ReasoningEffort.none] when reasoning should be switched off
  /// (or when the model does not support reasoning at all, in which case the
  /// caller omits the `reasoning` key instead of sending `none`).
  ///
  /// For a known model this guarantees the returned value is accepted, so a
  /// provider can never 400 in response to it. For an unknown model it
  /// returns [requested] unchanged.
  ReasoningEffort sanitize(ReasoningEffort? requested) {
    // Unknown capabilities → trust the user's explicit choice.
    if (!known) return requested ?? ReasoningEffort.none;
    if (!supportsReasoning) return ReasoningEffort.none;

    final requestedEffort = requested ?? defaultEffort ?? ReasoningEffort.none;

    // "Off" is only valid when reasoning is optional.
    if (requestedEffort == ReasoningEffort.none) {
      return reasoningMandatory
          ? (defaultEffort ?? ReasoningEffort.medium)
          : ReasoningEffort.none;
    }

    if (supportedEfforts.contains(requestedEffort)) return requestedEffort;

    // Pick the nearest accepted level. Ties resolve to the lower effort so
    // we never silently spend a user's token budget on more thinking than
    // they asked for.
    ReasoningEffort? best;
    var bestDistance = 1 << 30;
    for (final candidate in supportedEfforts) {
      final distance = (candidate.strength - requestedEffort.strength).abs();
      if (distance < bestDistance ||
          (distance == bestDistance &&
              best != null &&
              candidate.strength < best.strength)) {
        best = candidate;
        bestDistance = distance;
      }
    }
    return best ?? ReasoningEffort.none;
  }

  /// The efforts the UI should offer for this model, strongest first.
  ///
  /// Excludes [ReasoningEffort.none] when reasoning is mandatory, and is
  /// empty when the model is known not to support reasoning. For an unknown
  /// model every level is offered, since there is nothing to filter by.
  List<ReasoningEffort> get selectableEfforts {
    if (known && !supportsReasoning) return const [];
    if (known && supportedEfforts.isEmpty) return const [];
    final efforts =
        known ? List<ReasoningEffort>.of(supportedEfforts) : List.of(_kAllEfforts);
    efforts.removeWhere((e) => known && e == ReasoningEffort.none);
    if (known && reasoningMandatory) return efforts;
    return efforts..insert(0, ReasoningEffort.none);
  }

  /// Every effort Jusoor can express, strongest first.
  static const List<ReasoningEffort> _kAllEfforts = [
    ReasoningEffort.high,
    ReasoningEffort.medium,
    ReasoningEffort.low,
  ];
}
