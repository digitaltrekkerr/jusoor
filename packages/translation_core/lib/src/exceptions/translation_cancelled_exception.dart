// Copyright (c) 2026 Jusoor. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file in the root of the source tree.

/// Exception thrown when a translation request is cancelled by the user
/// (via a `CancelToken`) rather than failing on its own.
///
/// Distinct from [TranslationException] so that callers — notably the
/// `TranslationNotifier` fallback chain — can tell "user asked to stop"
/// apart from "request failed". A cancellation must never trigger a
/// fallback retry or a visible error; it only stops the current stream.
class TranslationCancelledException implements Exception {
  /// Creates a [TranslationCancelledException].
  const TranslationCancelledException();

  @override
  String toString() => 'TranslationCancelledException: translation cancelled';
}