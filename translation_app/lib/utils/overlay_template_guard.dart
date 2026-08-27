import 'package:translation_core/translation_core.dart';

/// Error returned by [overlayTemplateGuardError] when the selected overlay
/// template bakes its output language into the prompt body.
///
/// Fixed-language templates have no `{{target_language}}` placeholder, but
/// the floating overlay always carries a user-chosen target language (via
/// the `target` IPC field or the in-window language picker), so it cannot
/// drive them. The text must stay in sync with the message used by the IPC
/// path in `overlay_handlers.dart` so both surfaces reject the template
/// identically.
const String kOverlayFixedLanguageError =
    'Error: Selected template has a fixed output language and is not '
    'compatible with floating overlay translation. Please open app '
    'Settings to pick a different overlay template.';

/// Guards overlay translation (text AND image) against [PromptTemplate]s
/// whose output language is fixed.
///
/// Returns [kOverlayFixedLanguageError] when [template.outputLanguageFixed]
/// is `true`, otherwise `null` (translation may proceed). Shared by the
/// in-app overlay translate handler (`main.dart`) and the IPC overlay
/// handlers so every overlay entry point rejects fixed-language templates
/// with the same clear, actionable message.
String? overlayTemplateGuardError(PromptTemplate template) {
  if (template.outputLanguageFixed) {
    return kOverlayFixedLanguageError;
  }
  return null;
}