# Jusoor — Functional Change-Map after `158d206 "V1"` (up to HEAD + working tree)

Analysis base: static reading of git history and **current** source. No app/device run done.

## 0. Scope & commit inventory

```
git log --oneline 158d206..HEAD
  0ec39fa Drop maxOutputWords, fix Gemini HTTP 400, restore built-in prompts, theme overlay
  41ad43d Harden CI, factor shared Markdown helpers, share Dio factory
  fa1f9a1 V2 — apply 6 user-requested features
```

Plus **uncommitted working-tree changes** in `translation_app/lib/main.dart`
(overlay theme: handle `'system'`, default to `ThemeMode.system`, and a
`foregroundColor: onPrimary` on the overlay Translate button). **A build from
the working tree ≠ build from HEAD** — the uncommitted delta is included in
this map and must be part of any device test build.

Version: `translation_app/pubspec.yaml` = `0.1.5+2011` (HEAD). No bump is
present for the uncommitted overlay change — a maintainer committing it must
bump to `+2012` per the contribution rules.

---

## 1. Per-feature sections

### R1 — Articles stay Arabic-only regardless of app locale

**What changed**
- `translation_app/lib/screens/article_screen.dart:10-18` — added a doc comment
  declaring the invariant (no functional change; article content was already
  Arabic-only).
- `translation_app/test/articles_service_test.dart` (new, 6 tests) — guards
  that every `kAppArticles` id is 2-digit numeric, title/excerpt contain Arabic
  (`[\u0600-\u06FF]`), asset paths live under `assets/articles/*.md`, and every
  asset body loads non-empty.

**User-visible behavior to expect**
Nothing new vs V1: in both English and Arabic UI, the Articles/Support screens
still show the same Arabic titles/excerpts/bodies. The change is a guard, not a
feature.

**Verify on device**
1. `adb shell am start -n com.digitaltrekkerr.jusoor/.MainActivity`
2. Settings → locale = English (Settings → "اللغة/Language" if present; app
   locale override via `appLocaleProvider`), then Settings → Articles / Support.
3. Commit 3 sample titles into a notes app. Expected: all are Arabic
   (e.g. "مقدمة في الترجمة") even though the rest of the UI is English.
4. Repeat with locale = Arabic → same Arabic articles.
Pass: identical Arabic content in both locales; no English article copies.

---

### R2 — Profile edit forces API key before model

**What changed** — `translation_app/lib/screens/profile_edit_screen.dart`
- `_apiKeyHighlight` + `_apiKeyHighlightTimer`, `_flashApiKeyHighlight()`
  (lines 34-39, 59-69) — red (error) 2px border on the API Key field for 1.8 s.
- `_showModelAccessDialog()` (74-136) — bottom sheet shown when the user taps
  **Model** or **Vision Model** while `_selectedApiKeyId == null`, with two
  options: "اختر مفتاحًا موجودًا" (→ flashes highlight + opens key picker) and
  "إضافة مفتاح جديد" (→ pushes `ApiKeysScreen` fullscreen).
- Model/Vision fields now set `onTap: _canFetchModels ? _selectModel :
  _showModelAccessDialog` (lines 413-426, 441-451) instead of `null`.
- `_selectApiKey()` (279-314) — when zero API keys exist, navigates straight to
  `ApiKeysScreen` instead of showing a dead-end snackbar.
- API Key `InputDecorator` border/focusedBorder/enabledBorder now themed and
  highlight-aware (456-501).
- `translation_app/lib/screens/api_keys_screen.dart:32-54` — trailing
  "Add new key" `OutlinedButton` (`itemCount: apiKeys.length + 1`).

**User-visible behavior**
Tapping a model field before choosing an API key no longer silently ignores the
tap: a sheet explains the dependency and short-circuits to picking/creating a
key; the API Key field flashes red; a same-sheet path into the keys manager.

**Verify on device**
1. Settings → API Keys: if none exist, tap "Add new key". Create at least one,
   then delete all keys again (or start fresh) to test the empty path.
2. Settings → Profiles → New Profile. **Leave API Key = (None)**.
3. Tap the "Model" row. Expected: bottom sheet "يلزم تحديد مفتاح API أولًا".
4. Tap "اختر مفتاحًا موجودًا" → key picker sheet appears AND API Key field
   flashes red for ~1.8 s.
5. Re-tap Model while still `(None)` → tap "إضافة مفتاح جديد" → Api Keys
   screen opens. Add a key, back → API key now selected.
6. With no keys at all: Settings→Profiles→New→tap Model → the app opens the
   Api Keys screen directly (no snackbar, no dead-end).
7. Confirm the list now shows the "Add new key" CTA button at the bottom
   (`api_keys_screen.dart`).

---

### R3 — Thinking disabled by default + per-template switch

**What changed**
- `packages/translation_core/lib/src/models/prompt_template.dart:56-60,94` —
  new `enableThinking` field (default `false`), persisted as
  `json['enableThinking']`.
- `packages/translation_core/lib/src/models/translation_request.dart:71` —
  `enableThinking` default `false`.
- Providers:
  - Gemini `gemini_provider.dart:191-200, 259-266` — sends
    `generationConfig.thinkingConfig = {thinkingBudget: enableThinking ? -1 : 0}`
    **only** for models matched by `_supportsThinkingConfig` (225-227,
    regex `^gemini-(2\.5|3)`), i.e. 2.5/3 family only.
  - OpenRouter `openrouter_provider.dart:175-185, 262-266` — attaches
    `reasoning: {effort: 'low'}` when `request.enableThinking`, else strips it.
  - OpenAI-compatible `openai_compatible_provider.dart:108-117, 193-197` —
    attaches `reasoning_effort: 'low'` only for `_supportsReasoningEffort`
    models (`^(o1|o3|o4|gpt-5|gpt-oss)` or `deepseek-r1`), else strips it.
- Editor UI: `template_edit_screen.dart:195-215, 202-207` — "Enable thinking"
  switch in the Advanced ExpansionTile; flag round-trips through save (281-293)
  and load (84-86).
- `OpenRouterCapabilities` fetch (see §7 risk) was added but never wired in.

**User-visible behavior**
Templates default to no thinking. Flipping the "Enable thinking" switch stores
the flag in template JSON.

**⚠ Known gap (verified against actual code):** the flag is never propagated
from template → `TranslationRequest`. `translation_provider.dart:152-162` builds
`effectiveRequest` with only `substituteTargetLanguage` from the template;
`home_screen.dart:181-187` constructs the request without it; overlay
`main.dart:684-691` and `overlay_handlers.dart:187-194` likewise. Providers read
only `request.enableThinking`, which is therefore **always false on the wire**,
so the switch currently has zero effect. See §7 risk #1.

**Verify on device**
1. Template editor (Settings → Templates → 4b template → edit) → expand
   "Advanced" → flip "Enable thinking" → Save.
2. Re-open editor → switch persists.
3. Translate. Expected per commit intent: `reasoning`/`reasoning_effort`
   present. **Actual:** because of the gap, no reasoning params appear — even
   with the switch ON (confirm via wire test §2). Report as **FAIL / bug** if
   you confirm the switch-ON request still lacks reasoning.

---

### R4 — Stream default + word-cap → then removed

**What changed (final state after 0ec39fa)**
- `prompt_template.dart` / `translation_request.dart` — `maxOutputWords` and
  `max_tokens`/`maxOutputTokens` **removed entirely** (0ec39fa). `stream` field
  remains on both models, default `false`.
- Providers no longer emit any output-token cap on the wire:
  `gemini_provider.dart:191-200` (no `maxOutputTokens`), `openrouter_provider.dart:175-185`
  ("No output token cap is sent"), `openai_compatible_provider.dart:108-117`.
- Wire `stream` = `request.stream || provider-stream-default`:
  - providers all default `stream = true` (`gemini_provider.dart:53`,
    `openrouter_provider.dart:92`, `openai_compatible_provider.dart:43`);
  - request default `stream = false`;
  - → the effective wire stream is `false || true = true` everywhere.

**User-visible behavior**
- The Gemini HTTP 400 caused by a 20000-token cap disappears (that was the 0ec39fa
  fix motivation, §2).
- OpenRouter free-tier models with small max-context no longer reject requests.
- Output still streams (typed-out text) as in V1; "Stream output" switch has no
  wire effect (same plumbing gap as R3; `request.stream` is never set by app
  code). 0ec39fa's own tests acknowledge this ("the wire value is true until the
  caller explicitly disables streaming").
- `SettingsRepository.wordLimit` default changed **5000 → 10000**
  (`settings_repository.dart:239-240`) — the *input* word-limit dialog now
  allows 10k words on fresh installs (saved user value is preserved).

**Verify on device**
1. Template editor → Advanced confirms only two switches, **no** "Max output
   words" field (removed in 0ec39fa).
2. Home screen: enter >5000 words without a saved word_limit → no word-limit
   dialog until 10000 (fresh install).
3. Legacy template JSON with an old `maxOutputWords` key still opens/edits/saves
   (key is ignored on `fromJson` — covered by
   `prompt_template_test.dart` "legacy key ignored" test).

---

### R6 — `outputLanguageFixed` flag (fixed output, no selector)

**What changed**
- `prompt_template.dart:41-49,92,109,139` — `outputLanguageFixed` bool field
  (default false), JSON round-trip + copyWith + props.
- Home screen `home_screen.dart:142-159` (`_selectedTextTemplate`,
  `_isSelectedTemplateFixedLanguage`), `442-446` (language selector hidden via
  `Visibility(maintainState: true)`), `178-179` (target passed as `'auto'`).
- Overlay IPC `overlay_handlers.dart:147-161` (text path) and `251-261`
  (screenshot path) — reject a fixed-language overlay template with a clear
  English error message.
- Template editor `template_edit_screen.dart:186-192` — "Fixed output language"
  switch.

**User-visible behavior**
When the **selected text template** has the flag ON: home hides the
target-language dropdown; translation still runs, with target `'auto'` baked
into the prompt. The overlay (service path) refuses to run that template with
an actionable error.

**Verify on device**
1. Template editor → enable "Fixed output language" on a custom text template →
   Save → select it as the active text template.
2. Home: language selector row is gone (English/… dropdown disappears);
   translate still completes (prompt must carry the fixed target language).
   Confirm the request's target is effectively "auto".
3. Disable it → selector returns. Verify `maintainState: true` keeps the
   selected language value across the hide/show toggle.
4. Overlay: select the fixed template as overlay template; trigger overlay
   translation from home. Expected error in the overlay:
   "Selected template has a fixed output language and is not compatible…".

**⚠ Known gap:** the overlay has two translation paths. The IPC path in
`overlay_handlers.dart` rejects fixed templates, but the overlay UI's **own**
Translate/Screenshot buttons (`main.dart:_performTranslation`, `_performScreenshotTranslation`)
**do not** check `outputLanguageFixed` (no match for `outputLanguageFixed` in
`main.dart`). So the overlay can still run a fixed template if the user uses the
floating window controls directly — inconsistent with the IPC reject. See risk #2.

---

### R7 — Plain-copy default + copy/share/save options

**What changed**
- `packages/markdown_renderer/lib/src/utils/markdown_stripper.dart` (new) —
  `toPlainText(md)` wrapping `strip_markdown`'s `removeMd`, then
  `replaceAll(RegExp(r'\s+'),' ')` + trim. Dep added: `strip_markdown: ^1.0.1`
  (lock resolves 1.1.0). 12 tests.
- Kotlin mirror `TranslationOverlayService.kt:78-104` —
  `stripMarkdownForClipboard()` (regex-based, order: fenced blocks → inline code
  → links/images → headings/quotes → bullets/lists → HR → bold/italic →
  whitespace collapse). `writeClipboard` handler `949-964` now takes a `mode`
  arg: `mode == "markdown"` writes verbatim, otherwise strips.
- Home `_OutputArea` (`home_screen.dart:1055-1063,1070-1120,1141-1167`):
  short-press copy = plain (stripped); long-press copy = bottom sheet
  (plain / Markdown). Share (`285-398`): tap = 3-option sheet (plain text /
  Markdown `.md` file / Save-to-file), long-press = share plain.
- History detail (`history_detail_screen.dart:31-101,102-160,213-224`): new
  AppBar copy button (short=plain, long=options) and share button → three
  options (plain / `.md` file / save-to-file via system sheet).
- Overlay (`main.dart:468-488` copy with mode, `490-501` share, `507-529`
  save-to-file, `533-573` share sheet, `580-611` copy sheet, `1075-1076` share
  button, `1094-1096` copy button).
- 14 new ARB keys (`copyAsPlain`, `copyAsMarkdown`, `shareAsPlain`,
  `shareAsMarkdown`, `saveToFile`, `copyOptionsTitle`, `shareOptionsTitle`,
  `tplAdvancedTitle/Subtitle`, `tplEnableThinkingTitle/Subtitle`,
  `tplEnableStreamTitle/Subtitle`, `tplOutLangFixedTitle/Subtitle`) in en+ar.

**User-visible behavior**
- Copy default changes: pasted text no longer contains `**`, `#`, `[x](url)`.
- Long-press copy → choice sheet. Long-press share → direct plain share.
- Share now offers file (`.md`) and save-to-file alongside plain.

**Verify on device**
1. Produce a translation containing bold `**…**`, headings `#`, and a link.
2. Home: tap copy icon → open any text field → long-press → Paste. Expected
   plain text: `**` gone, headings stripped, link text `[...]` kept, no `#`.
3. Long-press copy → "نسخ كـ Markdown" → Paste → original `**`/`#` intact.
4. Share tap → 3 options sheet. "Plain" shares stripped text (system share
   sheet preview), "Markdown (.md)" shares a file, "Save to file" opens system
   share → pick Files → save destination.
5. History detail (History tab → tap a record): repeat 2-4 with the AppBar
   copy/share buttons.
6. Overlay: after a translation, tap copy → Paste plain; long-press copy →
   2-option sheet; share tap → 3-option sheet; long-press share → plain share.
7. **Wire check** `adb logcat -s ClipboardDebug:*`: line
   `write (plain): N chars (from M chars)` — N ≤ M shows the strip ran.

---

### 0ec39fa fix 1 — Drop `maxOutputWords` → no output cap on wire

Covered under R4 above. Device check: translating through `openrouter/free` or
any small-context model that previously HTTP-400'd on `max_tokens=20000` now
succeeds. The provider tests now assert `body.containsKey('max_tokens')` is
false (`openrouter_provider_test.dart`, `openai_compatible_provider_test.dart`).

### 0ec39fa fix 2 — Fix Gemini HTTP 400 on non-thinking models

**What changed** — `gemini_provider.dart:191-200`: `thinkingConfig` is emitted
only when the model matches `^gemini-(2\.5|3)` (see R3). Older/other models
(1.5, 2.0, Gemma) get a body identical to the pre-V2 format. Also a null-body
guard at `142-145` (`'Empty response body'`) plus new test.

**Verify on device**
1. Profile with a Gemini model **outside** the 2.5/3 family (e.g. set provider
   model to `gemini-2.0-flash` or a `gemini-1.5-*`) with a valid key.
2. Translate short text. Expected: works (no HTTP 400).
3. Same with `gemini-2.5-flash`: still works, and `logcat -s GeminiProvider:*`
   shows the "always thinks" warning only when thinking is OFF on a 2.5-pro
   model (informational).

### 0ec39fa fix 3 — "Reset to Default" restores the real built-in prompt

**What changed**
- `settings_repository.dart:108-126` — new `builtInSystemPromptFor(id)` static:
  `professional_translator_template` & `openai_translator_template` →
  `systemPromptTemplate`; `gemini_translator_template` →
  `geminiReconstructionTemplatePrompt`; else `null`.
- `template_edit_screen.dart:231-241` — `_resetSystemPrompt()` now resolves the
  built-in's own catalog prompt instead of the generic `_kDefaultSystemPrompt`.
- 4 new tests (`settings_repository_builtin_prompts_test.dart`).

**Verify on device**
1. Templates → edit the built-in "Gemini Reconstruction Translator" → alter the
   prompt to junk → tap "Reset to default". Expected: the long formatting-
   reconstruction prompt (talks about "broken syntax detection") returns, not
   the short generic one.
2. Same on "OpenRouter Translator" → generic expert prompt returns.
3. Custom template → reset → generic default prompt returns; unknown-id fallback
   is `null` (tested).

### 0ec39fa fix 4 + uncommitted — Overlay theming follows app theme

**What changed**
- `settings_repository.dart:75-79` — `themeModeKey` made **public** (overlay
  engine reads the same SharedPreferences directly).
- `main.dart:58-66, 68-89, 98-131` — overlay `MaterialApp` now uses
  `_overlayTheme(Brightness)` (same `#4F46E5` seed + M3) for light/dark with a
  `FutureBuilder<ThemeMode>` resolving `theme_mode` pref. The five hardcoded
  dark palette constants became theme getters (`_primaryColor`,
  `_surfaceColor`, `_surfaceContainerColor`, `_onSurfaceColor`,
  `_onSurfaceVariantColor`, `main.dart:156-162`), with `const` removed from all
  their usages.
- **UNCOMMITTED:** `_resolveOverlayThemeMode()` now maps `'system'` →
  `ThemeMode.system` and falls back to `system` (was `dark`) for absent values
  and errors; `snapshot.data ?? ThemeMode.system`; plus the overlay Translate
  `ElevatedButton` gains `foregroundColor: Theme.of(context).colorScheme.onPrimary`
  (`main.dart:988-995`) so the label stays legible on the themed primary in both
  modes.

**Behavior**
Overlay is light in light mode, dark in dark, and — with the uncommitted delta —
tracks the device when the app is set to System (previously `'system'` fell
through to `dark`). Without the uncommitted change, a stored `'system'` renders
dark.

**Verify on device**
1. Set app theme = Dark → start overlay (`settings` → show overlay /
   quick-settings tile) → overlay is dark.
2. Set Light → restart overlay service
   (`adb shell am force-stop com.digitaltrekkerr.jusoor`, relaunch) → overlay
   light.
3. Set System with device in light → overlay light; switch device to dark →
   re-open overlay → dark. (Note: theme is resolved once when the overlay
   engine starts; live switching requires re-showing the overlay — see risk #6.)
4. In light theme confirm the "Translate" label on the overlay is legible
   (dark text on indigo), i.e. not white-on-indigo.

---

### 41ad43d — CI split-per-ABI

**What changed** — `.github/workflows/release.yml`: SHA-pinned
`subosito/flutter-action` (v2.23.0) and `softprops/action-gh-release`
(v2.6.2); `flutter build apk --release --split-per-abi` (line 62); renames the
three ABI outputs to `jusoor-armeabi-v7a.apk`, `jusoor-arm64-v8a.apk`,
`jusoor-x86_64.apk`; publishes all three on the `build-<sha>` release (78-108).

**Verify on device**
Not a runtime feature. Build/CI check only: the GitHub Release must contain
exactly 3 APKs and the fail-closed debug-signature guard still gates. The APKs
are per-ABI — testers must pick their device's ABI
(`adb shell getprop ro.product.cpu.abi` → arm64-v8a for modern phones).

### 41ad43d — shared markdown helpers (`handleMarkdownLinkTap`, `buildBaseMarkdownStyleSheet`)

**What changed** — `packages/markdown_renderer/lib/src/widgets/markdown_view_helpers.dart` (new);
`markdown_view.dart` and `translation_app/lib/widgets/bidi_markdown_view.dart`
now delegate. **Behavior change:** `handleMarkdownLinkTap` (helpers:241-256)
now shows a confirmation dialog "Open external link?" for `http(s)` links
(helpers:261-279) before launching; non-http schemes launch immediately. V1
launched http(s) links directly with no prompt. This affects every rendered
Markdown surface (articles, history detail, home output, overlay output).

**Verify on device**
1. Any article/history with a link → tap it → confirmation dialog with the
   host name appears → Cancel does nothing; Open launches the browser.
2. `mailto:`/custom-scheme links still launch without a dialog.
Note: dialog strings are hardcoded English (`helpers:265,273,275`) — see risk #3.

### 41ad43d — shared `dio_factory`

**What changed** — `packages/translation_core/lib/src/utils/dio_factory.dart`,
`createTranslationDio()`: connect 10 s / receive 120 s / send 30 s; now the
default Dio for all three providers (`gemini_provider.dart:55`,
`openrouter_provider.dart:95`, `openai_compatible_provider.dart:45`). 3 tests.

**Verify on device**
Only observable with a flaky/slow endpoint: an unreachable host errors within
~10 s; a translation that must stream for >120 s will be cut by receive-timeout
(see risk #8; not easily device-testable without such an endpoint).

---

## 2. Risky / edge behaviors

1. **R3/R4 per-template switches are inert (top finding).**
   `enableThinking` and `stream` are persisted on the template but never copied
   into the `TranslationRequest` anywhere: `translation_provider.dart:152-162`,
   `home_screen.dart:181-187`, `main.dart:684-691`,
   `overlay_handlers.dart:187-194` all set only `substituteTargetLanguage`.
   Providers read exclusively `request.*`. Consequences: (a) "Enable thinking"
   never reaches the wire (always off — which matches its OFF default, so no
   regression, but the switch is dead); (b) "Stream output" is dead AND the
   wire always streams (`request.stream=false || provider.stream=true`), which
   contradicts R4's stated "disable stream by default". Code comment
   `gemini_provider.dart:58-61` claiming the endpoint reads the consolidated
   value is also wrong as written (it reads the constructor field).

2. **Overlay fixed-language inconsistency.** `overlay_handlers.dart:152,254`
   reject fixed-language templates, but the overlay's own controls
   (`main.dart:_performTranslation`/`_performScreenshotTranslation`) don't
   check the flag → a fixed template selected for the overlay can still run via
   the floating window UI, with a target that may be ignored by the baked-in
   prompt. Different error/no-error UX between the two paths.

3. **Hardcoded Arabic strings in new UI.** The copy/share/access sheets use
   inline `Text('مشاركة كنص عادي')`, `Text('إضافة مفتاح جديد')` etc.
   (`home_screen.dart:307,317,327,1081,1100`; `history_detail_screen.dart`
   sheets; `main.dart:543,552,561,590,599`; `profile_edit_screen.dart:92,102,110,118`)
   while the 14 new ARB keys (`copyAsPlain`, …) are **never referenced** →
   English-locale users see Arabic option labels; the l10n keys are dead.

4. **New external-link confirmation dialog** (helpers:241-279). Regression vs
   V1 one-tap launch; dialog text is hardcoded English and will look misplaced
   in the Arabic UI. Low risk but a UX change to sign off.

5. **Temp-file deletion race in share/save flows.** `_shareAsMarkdown`,
   `_saveToDownloads` (home:348-398), `history_detail_screen` equivalents and
   overlay `_saveTranslationToFile` (main:507-529) delete the temp `.md` in a
   `finally` right after `SharePlus.share()` resolves — which returns when the
   share sheet closes, not when the target consumed the file. Saving to Drive /
   Gmail / some file managers can capture a deleted file. Pre-existing pattern,
   but now replicated across 2 new per-surface flows (markdown share + save).

6. **Overlay theme resolved once, staleness + flash.** Theme is read in a
   `FutureBuilder` every time the overlay engine starts (main:98-131), then the
   engine is cached in `FlutterEngineCache`. Changing the app theme while the
   overlay service is alive does not restyle the overlay until it restarts.
   Also, before prefs resolve, the (uncommitted) code renders
   `ThemeMode.system`: a dark-mode user on a light device will see a light
   overlay flash for the first frames before it flips dark.

7. **`OpenRouterCapabilities` is dead + TTL claim is false.** The V2 commit
   message advertises "7-day TTL for /api/v1/models", but `openrouter_capabilities.dart`
   caches the snapshot in-memory forever (`_snapshot ??= await _fetch()`, lines
   116-118) with no expiry, and nothing in the app or providers imports it
   (only the barrel export `translation_core.dart:22`). Reasoning-capability
   gating is therefore unimplemented: `enableThinking` on OpenRouter force-sends
   `reasoning:{effort:low}` regardless of model capability (line 181-185).

8. **Dio timeouts change observable behavior.** New 120 s receive timeout can
   abort very long streaming translations; 10 s connect timeout is fine for
   normal use but may break slow API-key-bearer servers. No code computes the
   long-path case.

9. **`toPlainText` collapses all whitespace**, including paragraph/line
   boundaries inside code blocks, lists and tables
   (`markdown_stripper.dart:18`; Kotlin `TranslationOverlayService.kt:103`). A
   table-heavy or code-heavy translation copied/pasted becomes a single wall of
   text (`a   b\n\nc` → `a b c`). Intended for "natural prose" but a real
   content-fidelity loss to confirm with users. Kotlin regex strip also can't
   handle nested/backtick-in-code cases the Dart side handles; the two MUST
   diverge — flag any clipboard content where the Kotlin and Dart strips
   disagree.

10. **`substituteTargetLanguage` × `outputLanguageFixed` interplay.**
    Independent switches. A fixed-output template that leaves substitution ON
    will substitute `{{target_language}}` with `'auto'` on home (home:178-179)
    — models may emit odd "translate into auto" behavior. Also the language
    selector hide only applies to the **text** template selection
    (home:442-446); the **image** template fixed flag is ignored on home (image
    path still shows the selector).

11. **`AiOutputLanguageFixed` + `'auto'` no longer validated.** V1 asserted
    `targetLanguage != ''` (`translation_request.dart:101`), and `'auto'`
    passes; overlay defaults `'en'` (overlay_handlers:115) unchanged.

12. **Dead l10n + unused vars (minor).** `home_screen.dart:295-343` captures
    `ScaffoldMessenger` only to silence an analyzer warning via
    `// ignore: unused_local_variable`; several new ARB keys are unused (see #3).

13. **Version discipline.** Working tree is `+2011` with new uncommitted
    changes — a commit must bump to `+2012` (AGENTS.md version policy). And the
    0ec39fa commit message claims "289/289 passing" while listing totals that
    only sum to 289 across its own test files listing (151+52+52+23+11=289 ✓).

14. **Gemini `useStream` vs endpoint mismatch (latent).** `_buildEndpointUrl`
    (gemini_provider:57-66) branches on constructor-level `stream`, while the
    response parser branches on `useStream = request.stream || stream`
    (109-116). Any direct API caller passing `request.stream=true` with a
    provider constructed with `stream=false` gets a JSON body parsed as SSE.
    Currently unreachable from the app (request.stream never true), but a
    ticking bomb for the future template-stream wiring attempt.

---

## 3. DEVICE TEST CHECKLIST

Setup (do once):
```
adb install -r <abi>-release.apk            # build AFTER including uncommitted main.dart
adb shell appops set com.digitaltrekkerr.jusoor SYSTEM_ALERT_WINDOW allow
adb shell pm grant com.digitaltrekkerr.jusoor android.permission.POST_NOTIFICATIONS
adb shell am start -n com.digitaltrekkerr.jusoor/.MainActivity
adb logcat -s TranslationOverlay:* ClipboardDebug:* OverlayMain:* OverlayIPC:* GeminiProvider:* OpenRouterProvider:* OpenAIClient:*
```
Fixture: at least two API keys (OpenRouter with `openrouter/free`, Gemini with
`gemini-2.5-flash`); one custom text template with Markdown-heavy prompt.

### (a) UI screens
1. **API keys manager** — Settings→API Keys shows the trailing "Add new key"
   button; with zero keys the list still renders it. **Pass** = button visible
   and opens the create dialog.
2. **API key empty-state → profile** — Profiles→New→tap Model. **Pass** = Api
   Keys screen opens directly (no snackbar), not a dead-end.
3. **API-key-first gate** — Profiles→New with `(None)` key: tap Model and
   Vision Model. **Pass** = access sheet appears both times; API Key field
   flashes red ~1.8 s after "اختر مفتاحًا موجودًا".
4. **Key picker path** — from the access sheet pick an existing key. **Pass** =
   model list auto-fetches and dropdown becomes tappable.
5. **Template editor (Advanced)** — edit any template, expand "Advanced".
   **Pass** = exactly two switches (Enable thinking, Stream output) and **no**
   "Max output words" field.
6. **Template switch persistence** — flip both switches → Save → reopen.
   **Pass** = both restored.
7. **Reset-to-default (Gemini built-in)** — edit Gemographer/Gemini
   Reconstruction Translator, trash the prompt, reset. **Pass** = long
   formatting-reconstruction prompt returns.
8. **Reset-to-default (custom)** — create custom template, reset. **Pass** =
   generic `_kDefaultSystemPrompt` returns.
9. **R6 selector hide** — enable "Fixed output language" on the selected text
   template. **Pass** = home language dropdown disappears; disable → returns
   with prior selection retained (maintainState).
10. **R6 'auto' translate** — with R6 template active translate 2 sentences.
    **Pass** = completes; output reflects the template's baked language.
11. **Theme selector incl. System** — Settings theme segmented control shows
    System/Light/Dark (settings_screen.dart:650-673). **Pass** = System is
    selectable and persists across restart.

### (b) Translation wire behavior
12. **No max_tokens on wire** — translate via OpenRouter profile; `adb logcat`
    URLs/query (or a proxy/mitm) show body without `max_tokens`. **Pass** =
    absent. (Also directly: see provider logs from a mocked dio in unit tests —
    device proxy optional.)
13. **OpenRouter free-tier success** — translate long-ish text (5000+ words)
    via `openrouter/free`. **Pass** = completes without HTTP 400 (regression
    fix for oversized cap).
14. **Gemini 2.5 still works + thinking off** — translate with `gemini-2.5-flash`.
    **Pass** = completes; `GeminiProvider` log may show the 2.5-Pro-only warning
    only if using pro; body for 2.5-flash carries `thinkingConfig.thinkingBudget=0`.
15. **Gemini non-2.5/3 works (HTTP 400 fix)** — profile with `gemini-2.0-flash`
    (or a 1.5 model name). **Pass** = translate succeeds; logcat shows request
    body WITHOUT `thinkingConfig`.
16. **Thinking toggle is inert (known gap, confirm)** — flip Enable thinking ON
    on OpenRouter/OAI/Gemini template, translate. **Pass for "gap confirmed"** =
    no `reasoning`/`reasoning_effort` on the wire either way. Report as bug if
    you expected the switch to work.
17. **Stream toggle is inert (known gap, confirm)** — flip Stream output OFF,
    translate. **Pass for "gap confirmed"** = response still arrives as chunks
    (`stream:true` on wire). (Equal to V1 behavior.)
18. **Reasoning flag via direct caller only** — (optional, unit-level) /
    skip on device; covered by provider tests.
19. **Word-limit default 10000** — fresh install, type 6001 words. **Pass** =
    no dialog; at 10001 → dialog offers Cancel/Proceed.
20. **Fallback profile** — break primary key (delete it), keep fallback;
    translate. **Pass** = retry via fallback succeeds (translation_provider
    _tryFallback) — unchanged from V1 but sanity-check.

### (c) Overlay behavior
21. **Overlay dark theme** — app theme=Dark, open overlay. **Pass** = dark
    surface (not the old fixed-black palette, but dark-M3 seeded #4F46E5).
22. **Overlay light theme** — theme=Light, restart service, open overlay.
    **Pass** = light surface; Translate button label visible on indigo
    (onPrimary foreground).
23. **Overlay System theme** — theme=System, device=light → overlay light;
    device=dark → restart overlay → dark. **Pass** matches device.
24. **Overlay copy plain (default)** — translate → tap copy → paste into a
    text field. **Pass** = `**`, `#`, `[..](..)` gone; `logcat ClipboardDebug`
    shows `write (plain): N chars (from M chars)`.
25. **Overlay copy Markdown** — long-press copy → "نسخ كـ Markdown" → paste.
    **Pass** = raw `**`/`#` intact; log shows `write (markdown)`.
26. **Overlay share sheet** — tap share icon after translation. **Pass** = 3
    options; plain opens share sheet with stripped text.
27. **Overlay save-to-file** — tap "حفظ إلى ملف", pick Files → save. **Pass** =
    `.md` file lands at chosen destination *with content* (watch #5 file-race).
28. **Overlay fixed-language reject (IPC path)** — set overlay template to a
    fixed-language one, trigger translation from the main-app IPC flow. **Pass**
    = overlay shows the fixed-language incompatibility error, request never sent.
29. **Overlay fixed-language via own button (gap)** — same template, press the
    overlay's own Translate button. Expected-flag: it still translates
    (gap #2). Record observed behavior.
30. **Overlay screenshot with fixed template** — IPC screenshot path.
    **Pass** = same rejection error.
31. **Overlay screenshot (normal)** — non-fixed template, Screenshot button.
    **Pass** = capture dialog → translation completes and renders.

### (d) Files / import-export
32. **Markdown link confirm** — article or history page containing a link: tap
    it. **Pass** = "Open external link?" dialog with host; Cancel blocks;
    Open launches external browser.
33. **History copy plain** — History→detail→copy icon. **Pass** = clipboard
    plain; "Copied to clipboard" snackbar.
34. **History copy Markdown** — long-press copy → Markdown. **Pass** = raw md.
35. **History share plain / md / save** — share icon → all 3 options behave
    like #26/#27.
36. **Home share plain** — translate on home → share → plain. **Pass** =
    stripped text in share preview.
37. **Home share-as-markdown file delivery** — share → "Markdown (.md)" →
    receive via a target that copies file bytes (Files/Gdrive). **Pass** =
    file content present after pick (watch #5).
38. **Articles Arabic invariant** — locale=English, open Articles.
    **Pass** = titles/body Arabic (R1).
39. **RTL/plain strip sanity** — Arabic translation with `**نص**` and `#` →
    copy → paste. **Pass** = Arabic plain "نص" without markers.
40. **Legacy data upgrade** — install V1 APK, add a template, upgrade; open
    template editor. **Pass** = template loads; `outputLanguageFixed`/
    `enableThinking` default false; old `maxOutputWords` JSON ignored; then
    reset works per #7.

---

## Summary of must-action items before shipping
- **Wire the template → request plumbing** for `enableThinking`/`stream`
  (currently dead), or deliberately drop the switches.
- **Apply `outputLanguageFixed` check to the overlay's own Translate/Screenshot
  handlers** (main.dart) for parity with overlay_handlers.
- Replace the hardcoded Arabic bottom-sheet strings with the (existing) l10n
  keys; delete or implement `OpenRouterCapabilities` (no TTL exists);
  review the confirm-link dialog localization and the temp-file deletion race.