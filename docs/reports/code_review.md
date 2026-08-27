# Jusoor — Static review of post-V1 (`158d206`) changes

Scope: `fa1f9a1` V2, `41ad43d`, `0ec39fa`, and the uncommitted `main.dart` diff. All line numbers refer to the current working tree. Static analysis only; nothing was executed except the Dart SDK (one scratch script in `/tmp` verifying the OpenRouter JSON payload, plus `dart analyze` on both app and core, which pass clean).

---

## Severity-ranked findings

### CRITICAL

**C1. OpenRouter request body is built from UNESCAPED values substituted into a raw-JSON template → every request with the built-in prompt crashes with `FormatException` before the HTTP call.**

- File: `packages/translation_core/lib/src/providers/openrouter_provider.dart:167-172`
- Change: `translate()` was switched from `VariableSubstitutor.buildVariableMap(request, apiKey)` (which JSON-escapes values) to `VariableSubstitutor.buildRawVariableMap(request)` (raw, unescaped), then the result is fed to `jsonDecode`.
- Trigger: Any request whose `systemPrompt` or `inputText` contains a double quote, backslash, or raw newline — which the **default built-in `systemPromptTemplate` itself contains** (`Never say "I'm ready", ...` plus `\n` line breaks, see `settings_repository.dart:149,191`). Verified with a scratch script: `jsonDecode` throws `FormatException: Control character in string`. The same happens for any user text containing `"` or a newline.
- Result: The default OpenRouter home-screen flow (and overlay) fails before an HTTP request is even sent; surfaced to the user as `Unexpected error: FormatException: …`. The added tests miss it because they all use quote/newline-free prompts.
- Fix: For template-based bodies use the JSON-escaping map (`buildVariableMap(request, apiKey)`) exactly as in V1, or stop JSON-templating entirely and build the body programmatically (like `_buildVisionBody`). Keep `substituteTargetLanguage` handling.

---

### HIGH

**H1. Media-projection permission DENY never reaches the service → overlay left invisible and permanently stuck.**

- File: `translation_app/android/app/src/main/kotlin/com/digitaltrekkerr/jusoor/TranslationOverlayService.kt:490-526` (consumer) and `MediaProjectionRequestActivity.kt:32-47` (producer, unchanged but part of this rewritten flow).
- Trigger: In `captureScreen` the service sets `pendingScreenshotResult`, `isScreenshotInProgress = true`, and `setOverlayAlpha(0f)`, then starts `MediaProjectionRequestActivity`. When the user denies (or cancels) the capture dialog, `MediaProjectionRequestActivity.onActivityResult` only logs — it **does not broadcast** `PROJECTION_RESULT_ACTION`, so `onProjectionResult(...)` never runs.
- Result: `isScreenshotInProgress`, `isWaitingForProjection`, and `pendingScreenshotResult` stay set forever; the overlay stays at alpha 0 (invisible); every subsequent capture returns `IN_PROGRESS`; the Dart-side `captureScreen` future never resolves, leaving the overlay widget's `_isLoading = true` indefinitely. The overlay is unusable until the service/process is killed.
- Fix: On denial/cancel, broadcast a result (resultCode != OK) so `onProjectionResult` restores alpha, resets flags, and errors the pending result — or add a timeout fallback in the service that mirrors the Clipboard fallback pattern.
- Note: The broadcasting bits of the service were rewritten in V2 (`registerReceivers`/`onProjectionResult`) without fixing this producer/consumer gap; it also defeats the `windowFocusListener`/`ACTION_CLOSE_SYSTEM_DIALOGS` guards, which depend on these flags.

**H2. `reasoning: {effort: 'low'}` is sent to EVERY OpenRouter model when thinking is enabled; the capabilities API is never consulted (and is dead code with no TTL).**

- File: `packages/translation_core/lib/src/providers/openrouter_provider.dart:180-185` and `262-266`.
- Trigger: Enabling “thinking” on any template → the provider attaches `reasoning.effort=low` unconditionally. Models that don't support a `reasoning` block (the majority of OpenRouter catalog) may 400 or silently behave differently; models with **mandatory** reasoning whose `supported_efforts` exclude `low` (e.g. only `[high]`) will 400 — this is precisely the bug the new `OpenRouterCapabilities` class was built to prevent.
- File: `packages/translation_core/lib/src/providers/openrouter_capabilities.dart` (whole file) — the class is exported (`translation_core.dart:22`) but **never referenced anywhere** in the app or core. Despite the description “7-day TTL cache … JSON caching”, the implementation is a forever-lived in-memory snapshot (`_snapshot`), no TTL, no persistence, and `refresh()` clobbers a good snapshot with `null` on a transient API failure.
- Fix: Route the effort decision through `OpenRouterCapabilities.get(modelId)` in the provider (or the app layer): send `reasoning` only when `supportsReasoning`, use `recommendedEffort`, and skip it entirely for unknown models. If the long-lived/TTL cache is intended, implement it (timestamp + expiry + JSON storage); otherwise this feature ships broken and still risky.
- Also: `OpenRouterCapabilities.get()` has a benign-but-redundant concurrent-fetch race (`_snapshot ??= await _fetch()` reads the null then re-fetches on every concurrent caller).

**H3. The new template `enableThinking` and `stream` toggles never reach any `TranslationRequest` → the flagship V2 feature is inert app-wide.**

- File: `translation_app/lib/screens/template_edit_screen.dart:289-291` persists the flags; they are read back into `_enableThinking/_stream` (lines 84-86), but nothing forwards them.
- Evidence: `translation_provider.dart:152-162` (`effectiveRequest` omits both fields), `home_screen.dart:181-189`, `overlay_handlers.dart:187-194`/`312-321`, and `main.dart:684-691`/`808-817` all construct `TranslationRequest` without `enableThinking`/`stream`. A repo-wide grep finds the fields referenced only by the editor, models, and providers' tests.
- Result: The UI toggles (including localized copy “Switch to enable streaming translation output”) save and reload but change nothing at request time. Even the providers' carefully-built `request.stream`/`request.enableThinking` branches are unreachable from real flows.
- Fix: Propagate `template.enableThinking`/`template.stream` into the `TranslationRequest` in `translation_provider.translate()` (needs the resolved template in scope — it already is), and into the overlay request builders; the doc comments in `translation_request.dart:59-79` say the provider layer “silently downgrades” unsupported thinking, but currently the flag never arrives.

---

### MEDIUM

**M1. Gemini `_buildEndpointUrl()` reads the constructor `stream` field, not the consolidated `request.stream || stream` used elsewhere — URL and `responseType` disagree whenever they differ.**

- File: `packages/translation_core/lib/src/providers/gemini_provider.dart:57-66` vs `106-116`.
- Trigger: `translate()` picks the streaming handler via `useStream = request.stream || stream`, but `_buildEndpointUrl` (called by both handlers) checks only the constructor `stream`. With `stream:false` + `request.stream:true`, the streaming handler duplexes `:generateContent` (non-SSE) and then parses it as SSE; with `stream:true` + `request.stream:false` it sends `:streamGenerateContent?alt=sse` with `ResponseType.json`. Either way: hangs (until 120s receive timeout) or a parse error.
- Today this is latent because no caller sets `request.stream=true`; it becomes live the moment H3's wiring lands. The code comment (“we just read the consolidated value”) is wrong.
- Fix: Pass the resolved stream flag into `_buildEndpointUrl`/handlers.

**M2. Overlay widget in `main.dart` missing the `outputLanguageFixed` guard that the kernel IPC handler has — same feature, inconsistent behavior.**

- File: `translation_app/lib/main.dart:652-742` (`_performTranslation`) and `744-868` (`_performScreenshotTranslation`) conduct the translation without the `template.outputLanguageFixed` check added at `overlay_handlers.dart:152-161` / `251-261`.
- Trigger: User selects a fixed-output-language template for the overlay, then uses the in-app floating overlay widget: translation still runs, and the overlay language selector is silently ignored (prompt bakes its own language). The kernel path correctly rejects with an actionable message.
- Fix: Mirror the early-return guard (and the same `substituteTargetLanguage` propagation, which is also dropped here).

**M3. Overlay cancel can wedge: the widget-side subscription is never cancelled directly, and no timeout exists.**

- File: `translation_app/lib/main.dart:409-422` (`_handleCancel`) + `693-724` (`_performTranslation`).
- Trigger: User taps Cancel while the model is mid-stream. `_isCancelled=true` is only honored on the *next* `chunk`. If the stream stalls (long thinking, TCP hiccup, receive timeout), no chunk ever arrives: the connection stays open, `Completer` never completes, and the button shows “Cancelling…” forever. (The kernel `cancel_translation` path only cancels the kernel-side `streamTranslationSubscription`, not this widget-local subscription.)
- Fix: Keep a reference to the widget's subscription and `cancel()` it (plus `completer.complete()`) directly in `_handleCancel`.

**M4. Double Markdown stripping on overlay copy, with two different algorithms.**

- File: `translation_app/lib/main.dart:468-488` (`_copyText` sends `toPlainText(text)` for `mode:'plain'`) and `TranslationOverlayService.kt:949-964` (`writeClipboard` re-strips through `stripMarkdownForClipboard` whenever `mode != "markdown"`).
- Trigger: Every plain-text copy from the overlay passes through Dart's `strip_markdown` *and then* Kotlin's regex set. The two disagree: Kotlin replaces fenced code blocks with `" "` (dropping their content), Dart keeps code content; ordering diverges too. Results are content-dependent and not what either helper alone would produce.
- Fix: Pick one side as the source of truth — pass `mode: 'markdown'` with pre-stripped text (Dart is the steeper choice), or send raw text and let Kotlin strip (single pass).

**M5. Overlay theme mode is resolved once per engine lifetime and never refreshed.**

- File: `translation_app/lib/main.dart:68-89` + `98-103`.
- Trigger: The cached Flutter engine runs `overlayMain` once when the service starts; `_resolveOverlayThemeMode()` is a one-shot `FutureBuilder`. If the user changes the app theme afterwards, reopening the overlay (re-attaching the same engine → no widget-tree rebuild) still shows the old theme until the engine/process restarts.
- Fix: Re-read the pref on each overlay `show` (e.g. via the `show`/`clear_state` IPC message or a platform-channel theme callback).

---

### LOW

**L1. Unguarded `firstWhere` in `ProfileEditScreen` → `StateError` crash risk.**
`translation_app/lib/screens/profile_edit_screen.dart:492` and `:514` call `apiKeys.firstWhere((k) => k.id == _selectedApiKeyId).name` while `build` watches `apiKeysProvider`. If the selected key is deleted while the editor is on screen (the screen pushes `ApiKeysScreen` in the “add new key” path), the rebuild throws. `_loadProfile()` repairs orphaned ids only at load time. Fix: use `where(...).firstOrNull` with a fallback label.

**L2. `OpenRouterCapabilities.refresh()` discards a healthy snapshot on network error (assigns `null`), and concurrent `get()` calls both fetch.**
`openrouter_capabilities.dart:114-123`. Fix: keep last-good snapshot on failure; memoize the in-flight future.

**L3. Kotlin: `imageReader?.acquireLatestImage()` at `TranslationOverlayService.kt:630` is not wrapped; if the reader is closed concurrently (service destroyed during the 100/50 ms retry windows) it throws `IllegalStateException` on the main thread → crash.**

**L4. Kotlin: on the `Throwable` screenshot-processing path (`TranslationOverlayService.kt:701-713`) the partially-created `Bitmap` is not recycled → native memory leak on repeated capture errors.**

**L5. Dead code: `detachOverlayViews()` (`TranslationOverlayService.kt:549-573`) is never called. It also calls `wm.removeViewImmediate` on views that may already be removed elsewhere. Remove or wire it up.**

**L6. `_supportsThinkingConfig` regex `^gemini-(2\.5|3)` (`gemini_provider.dart:225-227`) does not match the hyphen variant `gemini-2-5-pro` that `_kGemini25ProPattern` explicitly recognizes; a `gemini-2-5-pro` (or `gemini-3.1-flash`) model would silently omit `thinkingConfig` even though it supports budgets, and `gemini-3.1` doesn't match `^gemini-3`? it does — but a model named `gemini-2.5-pro` with dots is fine; normalize the separator before matching for consistency.**

**L7. `_saveProfile` (`profile_edit_screen.dart:555-597`) validates the model but not the API key, so a profile can be saved with `apiKeyId = null`; downstream code degrades to “No API key configured” messages. Consider blocking save (or requiring it) since a profile without a key is unusable.**

**L8. Home screen fixed-language *image* templates: the `outputLanguageFixed` guard only affects the text-template selector; image translation paths can still run a fixed-language vision template with the stale target-language state.**

---

## Looks-correct (properly done)

- **Gemini `thinkingConfig` gating** (`gemini_provider.dart:191-200, 259-266`): attaching `thinkingConfig` only for `^gemini-(2.5|3)` correctly avoids the 400 from older/Gemma models that reject the unknown field — this is exactly the “Gemini HTTP 400” fix, and is well-reasoned (2.5/3.x accept `thinkingBudget: 0` / `-1`). The 2.5-Pro “always thinks” warning is tidy and non-intrusive.
- **Removal of `maxOutputTokens`/`max_tokens`** across providers removes the class of 400s from cap-incompatible free-tier and newer reasoning models; backward-compat is handled by simply ignoring the legacy `maxOutputWords` key on read (covered by `prompt_template_test.dart:306-353`).
- **OpenAI-Compatible `reasoning_effort` gating** (`openai_compatible_provider.dart:207-211`) is conservative (o1/o3/o4/gpt-5/gpt-oss/DeepSeek-R1), correctly re-applies the check on the vision `effectiveModel`, and removes the key when thinking is off — no risk to ordinary models.
- **`dio_factory.dart`** timeouts are sensible (10s connect fail-fast, 120s receive for long streams, 30s send). Per-provider `dio` injection keeps tests/hermeticity intact.
- **`markdown_renderer` sharing** (`markdown_view_helpers.dart`): factored link-tap + stylesheet, used by both `MarkdownView` and `BiDiMarkdownView`; http(s) links get a confirmation dialog, non-http schemes launch directly; blockquote accent still flips for RTL. `toPlainText` handles Arabic + links and has tests.
- **`overlay_handlers.dart` fixed-language rejection** is clear, actionable, and placed before profile/key resolution; kernel `cancel_translation` path resets globals and persists a placeholder history entry.
- **Kotlin service hygiene**: receivers registered `RECEIVER_NOT_EXPORTED` behind a version-safe helper with `try/catch`; `unregisterReceivers()` on destroy; `startForegroundCompat` matches the manifest `foregroundServiceType="specialUse|mediaProjection"`; MediaProjection callback stops/releases the virtual display; `ImageReader` sizing handles row padding and recycles bitmaps on success; clipboard path has a busy-guard, relay-cache fallback with TTL, and misses no double-`success` when the broadcast arrives late.
- **`_showModelAccessDialog` / highlight flow** in `profile_edit_screen.dart` cancels its timer on dispose and checks `mounted` before `setState` after the async timer.
- **`main.dart` overlay initialization**: `ErrorWidget.builder` + `_InitializationErrorApp` fallback and the `foregroundColor: onPrimary` override keep the button legible in light mode.