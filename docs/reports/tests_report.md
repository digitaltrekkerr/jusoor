# Jusoor Monorepo — Static Analysis & Test Report

Date: 2026-08-26 · Flutter 3.41.7 / Dart 3.10 · melos 7.5.1
Repo: `/home/t-space/space/main/translate` (@ commit `0ec39fa` + 1 uncommitted change, see Notes)

## 1. Background build status

A `flutter build apk --debug` was running in background (log `/tmp/opencode/build_debug.log`).
It **FAILED** — the log ends with:

```
Running Gradle task 'assembleDebug'...  114.5s
Gradle task assembleDebug failed with exit code 143
```

Exit 143 = SIGTERM (128+15); the Flutter tool was terminated mid-Gradle run, so no apk was produced
(no "Built build/app/outputs/flutter-apk/app-debug.apk"). No `flutter`/`melos`/`dart` command touched
the build log until the process had exited and the pub/startup locks had cleared.

Two orphaned `flutter_tester` processes (PPID 1, leftover from an interrupted prior test session,
still holding `translation_core` test resources) were killed before analysis/tests started.

## 2. Exact commands run

| # | Command | Dir | Result |
|---|---------|-----|--------|
| 1 | `melos analyze` (`melos exec -- flutter analyze`, 5 pkgs concurrent) | repo root | FAILED at tool level — cross-package Flutter startup-lock contention ("Waiting for another flutter command to release the startup lock…"); the whole pipeline was then SIGTERM’d (exit 143). Per-package runs below are the correct signal. |
| 2 | `flutter analyze` (translation_core via `melos exec --concurrency 1`, file_handler, history, markdown_renderer, translation_app individually) | each package | **No issues found** in all 5 packages |
| 3 | `flutter test` per package (serialized; `--concurrency=1` for translation_app), captured to `/tmp/opencode/test_*.log` | each package | **All tests passed** — 289/289 |

> Why per-package rather than `melos run test` as one invocation: the monorepo’s melos scripts run
> `melos exec -- flutter …`, which launches all packages concurrently; every `flutter` invocation does a
> `pub get` that holds the single Flutter startup lock, so the concurrent runs deadlock/wait and the
> environment’s watchdog SIGTERMs the group (this also killed the background build — exit 143).
> Running the exact same per-package `flutter analyze` / `flutter test` commands serially avoids the
> contention and reproduces `melos analyze` / `melos run test` semantics faithfully.

## 3. Static analysis (melos analyze)

All 5 packages: **clean, 0 issues** (equates to the melos script once serialized):

| Package | Analysis result |
|---------|-----------------|
| packages/translation_core | No issues found (3.1 s) |
| packages/file_handler | No issues found (16.1 s) |
| packages/history | No issues found (16.2 s) |
| packages/markdown_renderer | No issues found (3.4 s) |
| translation_app | No issues found (32.2 s) |

## 4. Test results (melos run test)

**Overall: 289/289 tests passed — no failures in any package.**

| Package | Tests | Files | Result |
|---------|-------|-------|--------|
| packages/translation_core | **151** | 12 | ✅ All passed |
| translation_app | **52** | 5 | ✅ All passed |
| packages/file_handler | **52** | 6 | ✅ All passed |
| packages/markdown_renderer | **23** | 2 | ✅ All passed |
| packages/history | **11** | 1 | ✅ All passed |

Grand total **289** — exactly the number declared in the last commit message (0ec39fa).

### Per-file breakdown

**translation_core (151):** variable_substitutor 25 · prompt_template 31 · sse_parser 12 ·
provider_profile 18 · gemini_provider 21 · provider_type 11 · dio_factory 3 ·
response_path_extractor 8 · word_counter 11 · provider_factory 2 ·
openrouter_provider 4 · openai_compatible_provider 5

**translation_app (52):** widget_test 1 · update_checker_service_test · articles_service_test ·
services/settings_repository_builtin_prompts_test 4 · widgets/bidi_markdown_view_test

**file_handler (52):** html_parser 19 · text_chunker 11 · parser_factory 11 · markdown_parser 8 ·
chunk_merger 5 · plain_text_parser 4

**markdown_renderer (23):** markdown_stripper_test 12 · markdown_view_test 11

**history (11):** translation_dao_test 11

## 5. Targeted regression-verification (recent fixes)

### 5.1 gemini_provider_test — NO max_tokens/maxOutputTokens on wire; thinkingConfig only for 2.5/3 — **PARTIAL / GAP**

- The **source** implements both fixes (`packages/translation_core/lib/src/providers/gemini_provider.dart`):
  - `_buildTextBody` sends `generationConfig` with **no output-token cap** at all (comment: "No output
    token cap is sent — the provider applies its own default", line 192).
  - `thinkingConfig` is attached **only when** `_supportsThinkingConfig(model)` matches
    `RegExp(r'^gemini-(2\.5|3)')` (lines 196–200, 225–227); the vision body applies the same guard
    against `visionModel ?? model` (lines 259–266).
- **The test file does NOT contain any assertion covering this.** `gemini_provider_test.dart` was read
  in full (646 lines) and grepped; it never mentions `max_tokens`, `maxOutputTokens`, or `thinkingConfig`.
  The +44 added to this file by commit `0ec39fa` only added a *"null response body → TranslationException"
  group — no wire-format regression test. **These two regression assertions are missing for Gemini.**
- Equivalent wire-cap assertions **do exist for the other two providers** and pass:
  - `openrouter_provider_test.dart:109–126` — "no max_tokens key regardless of request"
    (`expect(body.containsKey('max_tokens'), isFalse)`, reason "output caps were removed").
  - `openai_compatible_provider_test.dart:146–168` — "no max_tokens key regardless of request"
    (same assertion; gpt-5.x 400 rationale at lines 68–69).

### 5.2 prompt_template_test — legacy JSON with `maxOutputWords` loads via fromJson — ✅ PRESENT & PASSING

`prompt_template_test.dart` (fromJson group):
- `fromJson reads new fields when present` (lines 306–322): JSON includes legacy `'maxOutputWords': 5000`
  alongside the new fields; `PromptTemplate.fromJson(json)` loads it without error and the legacy key is
  ignored. ✔
- `fromJson handles missing new fields with defaults (back-compat)` (lines 288–304) ✔
- `toJson includes new fields` (341–353) asserts `json.containsKey('maxOutputWords') == false` — the removed
  key is never written back. ✔

### 5.3 SettingsRepository built-in prompts — ✅ PRESENT & PASSING (4 tests)

`translation_app/test/services/settings_repository_builtin_prompts_test.dart` (verified when run
individually and within the full app suite — 4/4 green):
- `builtInSystemPromptFor('gemini_translator_template')` returns the real
  `SettingsRepository.geminiReconstructionTemplatePrompt` (reconstruction prompt, not a placeholder). ✔
- Generic expert prompt returned for `professional_translator_template` / `openai_translator_template`. ✔
- All built-in prompts contain `{{target_language}}`. ✔
- **Fallback for unknown ids returns `null`** (`'nope'` and timestamp-style custom ids). ✔

Note: the task’s example key was `'gemini_reconstruction'`; the actual catalog id in the codebase is
`gemini_translator_template`, which resolves to the `geminiReconstructionTemplatePrompt` string — the
source fields exist at `settings_repository.dart:116` (`builtInSystemPromptFor`), `:142`, `:187`.

### 5.4 dio_factory_test — timeouts + no-base-options guard — ✅ timeouts present; base-options guard NOT asserted

`packages/translation_core/test/dio_factory_test.dart` (3 tests, all pass):
- connectTimeout 10 s · receiveTimeout 120 s · sendTimeout 30 s. ✔
- **There is no explicit baseUrl/base-options assertion in the test.** The factory source
  (`lib/src/utils/dio_factory.dart`) builds `BaseOptions` with timeouts only — no `baseUrl` is set (a
  deliberate guard: providers must supply full endpoints) — but nothing in the test asserts it. If the
  intent was for the test to guard the absence of `baseUrl`/options leakage, **that assertion is missing**.

### 5.5 markdown_stripper_test — 12 tests — ✅ PRESENT & PASSING

`packages/markdown_renderer/test/markdown_stripper_test.dart` has **exactly 12 tests**: bold, italic,
headers, links (text kept), inline code backticks, fenced code blocks, whitespace collapsing, trimming,
plain text passthrough, Arabic, empty string, nested markdown. All pass inside the 23-test
markdown_renderer suite.

### 5.6 openrouter_capabilities cache test — ❌ NOT PRESENT

- Source exists: `packages/translation_core/lib/src/providers/openrouter_capabilities.dart`
  (`OpenRouterReasoningCapability`, immutable `OpenRouterCapabilitiesSnapshot`, and `OpenRouterCapabilities`
  whose `get()` caches the fetch via `_snapshot ??= await _fetch()`, lines 114–117).
- **No test file references `OpenRouterCapabilities` anywhere in the monorepo** (grepped all
  `packages/*/test` and `translation_app/test`). The in-memory cache behaviour and the
  `supportsReasoning` / `isMandatory` / `recommendedEffort` logic are untested. The class was added in
  commit `fa1f9a1` with no accompanying test.

## 6. Failures

None. Every executed test passed in every package. The only "red" items are two *missing* regression
tests (Sections 5.1 and 5.6) and the non-asserted base-options guard (5.4) — all three are gaps, not
failing runs.

## 7. Notes / environment observations

- The background `flutter build apk --debug` failed with SIGTERM (exit 143) before producing an APK.
- `melos analyze`/`melos run test` as a single concurrent invocation malfunctioned in this environment
  due to Flutter startup-lock contention across packages plus an external kill (exit 143). Serial
  per-package equivalents were used and gave clean results; CI should consider `--concurrency 1`.
- No source files were modified during this verification. One pre-existing uncommitted change remains:
  `translation_app/lib/main.dart` (theme-overlay: `ThemeMode.system` defaulting + `onPrimary` foreground,
  +16/−5). Not part of this run’s scope.
- Version file still at `0.1.5+2011` (no bump needed for a read-only verification).