import 'package:flutter/material.dart';

import 'package:translation_app/widgets/bidi_markdown_view.dart';

/// RTL/LTR direction for a single text field, shared between the compact
/// input and its full-screen editor. Owns the sticky `previous` value that
/// [BiDiMarkdownView.detectDirection] uses for hysteresis.
class InputDirectionController extends ValueNotifier<TextDirection> {
  InputDirectionController() : super(TextDirection.ltr);

  /// Recompute from [text], feeding the current value back as `previous`.
  void update(String text, {TextDirection fallback = TextDirection.ltr}) {
    final next = BiDiMarkdownView.detectDirection(
      text,
      fallback: fallback,
      previous: value,
    );
    // Assign only on change to avoid notifying listeners on every keystroke.
    if (next != value) {
      value = next;
    }
  }

  /// One-shot detection with no hysteresis (initial mount / route re-entry).
  void seed(String text, {TextDirection fallback = TextDirection.ltr}) {
    value = BiDiMarkdownView.detectDirection(text, fallback: fallback);
  }
}
