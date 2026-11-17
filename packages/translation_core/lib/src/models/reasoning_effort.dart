// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

/// Reasoning effort levels offered to the user.
///
/// Jusoor intentionally exposes only a small, safe subset of the values
/// OpenRouter accepts. In particular `minimal`, `xhigh` and `max` are
/// deliberately **not** offered — every level we do offer is one that the
/// vast majority of reasoning models accept, which keeps the capability
/// gating in [ModelCapabilities] simple and predictable.
///
/// The wire value for every level is its own name, so `ReasoningEffort.high`
/// is sent as `"high"`.
enum ReasoningEffort {
  /// Reasoning is turned off.
  ///
  /// **This is not sent as `effort: "none"` on the wire.** OpenRouter
  /// rejects `"none"` on models whose reasoning is mandatory, so a request
  /// built for [none] simply omits the `reasoning` key entirely.
  none,

  /// A smaller portion of the token budget is spent reasoning.
  low,

  /// A moderate portion of the token budget is spent reasoning.
  medium,

  /// A large portion of the token budget is spent reasoning.
  high;

  /// The string sent to the provider.
  ///
  /// Only meaningful for [low], [medium] and [high]; callers building a
  /// request body must special-case [none] by omitting the key instead of
  /// calling this getter.
  String get wireValue => name;

  /// Relative reasoning strength, used for clamping.
  ///
  /// A higher number means "reasons more".
  int get strength {
    switch (this) {
      case ReasoningEffort.none:
        return 0;
      case ReasoningEffort.low:
        return 1;
      case ReasoningEffort.medium:
        return 2;
      case ReasoningEffort.high:
        return 3;
    }
  }

  /// Parses a persisted wire value back into a [ReasoningEffort].
  ///
  /// Returns `null` for unknown or absent values so that old persisted
  /// profiles keep working instead of throwing.
  static ReasoningEffort? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final effort in ReasoningEffort.values) {
      if (effort.name == value) return effort;
    }
    return null;
  }

  /// Normalizes an arbitrary provider-reported effort down to a level we
  /// can actually represent.
  ///
  /// OpenRouter may report efforts we never expose (`minimal`, `xhigh`,
  /// `max`). They are folded onto the nearest level we do support so the
  /// comparison against [supportedEfforts] is meaningful.
  static ReasoningEffort normalize(String value) {
    switch (value) {
      case 'none':
      case 'minimal':
        return ReasoningEffort.none;
      case 'low':
        return ReasoningEffort.low;
      case 'medium':
        return ReasoningEffort.medium;
      case 'high':
        return ReasoningEffort.high;
      case 'xhigh':
      case 'max':
        return ReasoningEffort.high;
      default:
        return ReasoningEffort.medium;
    }
  }
}
