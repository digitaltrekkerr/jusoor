import 'package:flutter/material.dart';

/// Minimum allowed text size in px (logical pixels).
const int kTextSizeMinPx = 10;

/// Maximum allowed text size in px (logical pixels).
const int kTextSizeMaxPx = 40;

/// Fallback body font size (Material 3 bodyMedium) used when a theme lacks
/// an explicit size or when basePx is non-positive.
const double kFallbackBodyFontPx = 14.0;

/// Clamps a nullable px value into [kTextSizeMinPx, kTextSizeMaxPx].
///
/// `null` stays `null` (meaning "system/inherit"); out-of-range or
/// unparsable inputs are clamped, never throw.
int? clampTextSizePx(int? px) {
  if (px == null) return null;
  if (px < kTextSizeMinPx) return kTextSizeMinPx;
  if (px > kTextSizeMaxPx) return kTextSizeMaxPx;
  return px;
}

/// Resolution order for translation output: output override ?? global ?? null.
///
/// Both inputs are clamped before resolving.
int? resolveOutputTextSizePx(int? globalPx, int? outputPx) {
  final g = clampTextSizePx(globalPx);
  final o = clampTextSizePx(outputPx);
  return o ?? g;
}

/// Resolves the effective [TextScaler] for a given px preference.
///
/// Returns [system] verbatim when [px] is null so that "System" keeps
/// tracking the ambient (OS) scaler live. Otherwise returns a linear scaler
/// mapping body text to [px] logical pixels, using [basePx] as the base size
/// (guarded against non-positive values).
TextScaler resolveTextScaler({
  int? px,
  required double basePx,
  required TextScaler system,
}) {
  final clamped = clampTextSizePx(px);
  if (clamped == null) return system;
  final base = basePx <= 0 ? kFallbackBodyFontPx : basePx;
  return TextScaler.linear(clamped / base);
}

/// Returns the body-medium font size of a [TextTheme], falling back to
/// [kFallbackBodyFontPx] when absent.
double bodyBaseFontPx(TextTheme t) {
  final size = t.bodyMedium?.fontSize;
  if (size == null || size <= 0) return kFallbackBodyFontPx;
  return size;
}