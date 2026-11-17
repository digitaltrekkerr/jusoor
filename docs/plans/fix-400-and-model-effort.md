# Plan — Fix the Claude Haiku 5.5 image 400 + add effort (OpenRouter only)

Status: **plan only** (no code written yet)
Scope: `packages/translation_core` (engine) + `translation_app` (capture + settings UI)
Next version after this lands: `0.1.9+2018` (read from `pubspec.yaml`, bump `+2017` → `+2018` per AGENTS.md)

---

## 0. Decisions locked in by the user

1. **Effort is offered in the model picker of every provider's template**, with exactly four
   variants: **`none` / `low` / `medium` / `high`**.
2. **Effort is functional only on the OpenRouter provider.** On every other provider the
   control is visible but disabled with an explanatory note — matching the existing
   pattern of model/vision-model fields living in the same picker.
3. `none` means **omit the `reasoning` key entirely**. It is *not* sent as `effort:"none"`
   — OpenRouter rejects `none` on models where reasoning is mandatory.

---

## 1. The Claude 400 — root cause (confirmed)

**`anthropic/claude-haiku-5.5` does accept images.** Verified live from OpenRouter's API:

```
architecture.input_modalities = ["text", "image", "file"]   context = 1,000,000
reasoning = { mandatory: false, supported_efforts: [max, xhigh, high, medium, low] }
```

So this is a **payload problem, not a capability problem.** The asymmetry the user reports
(GPT-6-Luna fine, Claude 400) is explained by Anthropic's documented hard limits, which
OpenAI does not enforce:

| Anthropic limit (official docs) | Value |
|---|---|
| Max dimensions per image | **8000 × 8000 px** — exceeding it is *rejected with `invalid_request_error`*, not downscaled |
| Max size per image (base64) | **10 MB** direct API, **5 MB** on Bedrock / Google Cloud (OpenRouter routes to partners) |
| Supported formats | JPEG, PNG, GIF, WebP (animated unsupported, first frame only) |

And the app currently sends **raw, unresized PNG screenshots**:

| Site | Code |
|---|---|
| `overlay_handlers.dart:377` | `imageBase64: base64Encode(imageBytes), imageMimeType: 'image/png'` |
| `main.dart:1033` | `imageBase64: base64Encode(imageBytes), imageMimeType: 'image/png'` |
| `home_screen.dart:248` | `imageBase64: base64Encode(bytes), imageMimeType: mimeType` |

There is **no resize, recompress, or size guard anywhere in the codebase.** A full-screen PNG
at native resolution (and `OverlaySizeMode.full` explicitly captures the whole screen)
routinely exceeds 5 MB of base64. GPT models silently downscale oversized images; Anthropic
hard-rejects them → exactly the observed behaviour.

Fixes in **Phase B0** below.

---

## Phase A — Surface the real error (prerequisite, unchanged in intent)

All three providers currently discard the server's explanation:

```dart
throw TranslationException(e.message ?? 'HTTP request failed',  // Dio's generic blurb
    statusCode: e.response?.statusCode);                       // e.response.data DROPPED
```

`DioException.message` for a 400 is literally the generic "validateStatus" text. Nothing can
be fixed reliably until the real body reaches the UI.

**A1. New `packages/translation_core/lib/src/utils/dio_error_extractor.dart`**

`String describeDioError(DioException e, {String? provider})`:

1. `e.response?.data == null` → fall back to `e.message` (timeouts, connection errors).
2. `Map` body → read in order: `error.message`, `error.metadata.raw`, `error`, `message`,
   `detail`; append `metadata.provider_name` when present.
   OpenRouter 400s look like `{"error":{"message":"…","code":400,"metadata":{…}}}`.
3. `String` body → try `jsonDecode` and recurse into (2); else strip HTML tags.
4. Prefix provider + status: `OpenRouter 400: <reason>`.
5. Truncate at 500 chars so a huge body can't blow up the snackbar.

**A2.** Wire into all 3 providers, every catch block (translate **and** fetchModels), and
export from `lib/translation_core.dart`.

**A3.** Table-driven tests: OpenRouter JSON error, Gemini `INVALID_ARGUMENT` body,
plain-string body, HTML body, `null` body.

---

## Phase B0 — Fix the image 400 (highest priority; independent of effort)

### B0.1 Resize + recompress at capture — `translation_app/lib/utils/image_payload.dart`

One helper, called from all four capture sites so `imageBase64` and `imageMimeType` can
never drift apart:

- Decode with `ui.instantiateImageCodec(..., targetWidth/targetHeight)` capping the **long
  edge at 1568 px** — Anthropic's standard-tier long edge, which also caps the image at
  ~1568 visual tokens.
- Re-encode **JPEG, quality 85** (lossy = far smaller than PNG). Anthropic warns that heavy
  compression hurts text legibility, so never re-encode an already-JPEG more than once.
- Downshift ladder if the payload is still large: quality 85 → 75 → 65, then long edge
  1280 → 1024.
- **Hard stop: estimated base64 ≤ 4.5 MB** — deliberately under the 5 MB partner limit that
  Bedrock/Vertex enforce, so we fail locally instead of at the API.
- Mime whitelist `image/jpeg | image/png | image/gif | image/webp`; anything else is coerced
  to `image/jpeg`. Invalid base64 → clear local error.

Apply at: `home_screen.dart:248`, `overlay_handlers.dart:377`, `main.dart:1033`,
`share_intent_handler.dart:118/143/190`.

> Why JPEG rather than PNG: a 1080×2400 screen PNG is 1–3 MB; the same frame as JPEG q85 is
> typically 150–400 KB. This alone moves essentially every screenshot under every limit.

### B0.2 Pure-Dart guard in core — `translation_core/lib/src/utils/image_payload_guard.dart`

Belt-and-braces so a bypassed or regressed app layer still fails fast with a *useful*
message instead of a mystery 400:

- Mime whitelist, base64 alphabet validation, estimated decoded byte size.
- Estimated size > 4.5 MB → throw locally, before the HTTP call, naming the limit.
- Called from the top of every provider's `translate()` when `imageBase64 != null`.

### B0.3 Better residual error

Existing code only special-cases **404** for a vision-incapable model. Extend to:

- `400` + image present → message naming Anthropic's real limits (8000×8000, 5 MB) and
  noting that JPEG conversion is applied, so the user knows it's not their model choice.
- Also mention that some partners enforce 5 MB even when the direct API allows 10 MB.

### B0.4 Tests

Helper: oversize payload → clamped to ≤ 1568 px long edge / ≤ 4.5 MB; already-small image
passes through untouched; non-whitelisted mime → coerced; > 4.5 MB after the ladder →
throws locally with no HTTP call; guard rejects bad base64.

---

## Phase C — Effort (OpenRouter only, 4 variants)

### C1. Enum — `lib/src/models/reasoning_effort.dart`

```dart
enum ReasoningEffort { none, low, medium, high }
```

- `none` ⇒ **omit the `reasoning` key** (never send `effort:"none"`).
- `xhigh`/`max`/`minimal` are deliberately **not** offered — a safe subset of what OpenRouter
  accepts. Clamping (§C5) still maps downward when a model supports only e.g. `[high, low]`.

### C2. `TranslationRequest` gains

- `ReasoningEffort? reasoningEffort` — `null` = send nothing (today's wire shape).
- `bool reasoningExclude` (default `true`) — never stream raw thinking tokens into a
  translation UI. Sets `reasoning.exclude`.
- `toJson` / `fromJson` / `copyWith` / `props`; `fromJson` ignores a missing key for
  back-compat with old persisted requests.

### C3. `ProviderProfile` persists it

- `String? reasoningEffort` (wire string, not the enum name, so JSON stays forward-compatible)
  + `bool reasoningExclude`.
- Default `null` / `true` ⇒ byte-identical body to today.

### C4. Wire mapping — OpenRouter provider only

`_buildTextBody` + `_buildVisionBody`, when effort is non-null:

```json
"reasoning": { "effort": "medium", "exclude": true }
```

- Never combine `effort` with `max_tokens` (docs: "either `effort` or `max_tokens` but not both").
- **No changes to `gemini_provider.dart` or `openai_compatible_provider.dart` bodies** — they
  stay exactly as they are. Effort is OpenRouter-only per the decision above.

### C5. Capability gating — what stops this from creating new 400s

OpenRouter's docs are explicit: *"an update with an effort the model does not support is
rejected with a 400."* Non-reasoning and router models (`openrouter/auto`, `openrouter/free`)
omit the `reasoning` field entirely. So gating is mandatory, not optional.

- Add **non-breaking** `Future<List<ModelCapabilities>> fetchModelCapabilities()` alongside
  the existing `fetchModels()`. OpenRouter: read `reasoning.supported_efforts`,
  `reasoning.default_effort`, `reasoning.default_enabled`, `reasoning.mandatory`,
  `reasoning.supports_max_tokens` from `GET /api/v1/models`. `supported_efforts` arrives
  **descending (highest first)**.
- Sanitize rules (shared, unit-tested helper):
  1. No reasoning support → **omit** the `reasoning` key.
  2. `mandatory: true` → never send `none`; clamp to `default_effort`.
  3. Requested effort ∉ `supported_efforts` → clamp to the nearest supported; **never** send
     a value the model rejects.
- Cache in memory; refresh on pull-to-refresh.

### C6. UI — inside the existing model picker

- `profile_edit_screen.dart` — effort selector beside **Model** (~line 456) and **Vision
  model** (~line 501). Options: `Auto (model default)` + capability-filtered
  `none/low/medium/high`.
- Helper text: higher effort = slower + more tokens.
- **Non-OpenRouter profiles:** control rendered but disabled, with a note that effort is
  available on the OpenRouter provider only.
- Fetch capabilities on screen open and whenever the selected model changes.
- Localize in the `.arb` source **and** `app_localizations_ar.dart`
  (⚠️ that file is already modified in the working tree — add alongside, don't overwrite).

---

## Phase D — Guardrails & tests

**Must-update existing regression guards** (they currently assert reasoning is *never* on the wire):

- `openrouter_provider_test.dart:43-95` → assert absent **when effort is null**, present when set.
- `openai_compatible_provider_test.dart:43-95` → unchanged (no effort support; keep asserting absent).
- `gemini_provider_test.dart:326-372` → unchanged in substance; keep asserting `thinkingConfig` absent.
- `prompt_template_test.dart:265` → V2 thinking/stream back-compat test.

**New tests:**

- OpenRouter: no `reasoning` when null; `{effort, exclude}` when set; `none` → key omitted;
  unsupported effort clamped to nearest supported; `mandatory` model never gets `none`;
  both text **and** vision bodies.
- Capability gating: table-driven over real `supported_efforts` sets
  (e.g. Claude Haiku 5.5 = `[max,xhigh,high,medium,low]`, Gemini 3.8 Flash = `[high,medium,low]`,
  `openrouter/free` = no `reasoning` field at all).
- Non-OpenRouter profiles never emit `reasoning`, regardless of stored effort.
- Image payload: resize/recompress/size-cap ladder + local guard (Phase B0).
- `dio_error_extractor` (Phase A).
- **Empty-output guard** (documented trap): reasoning tokens count against `max_tokens`, so a
  small budget yields `finish_reason:"length"` with empty content. Detect and surface
  "the model spent its budget thinking" rather than an empty translation.
- **Streaming leak guard**: a chunk with `delta.reasoning` + `delta.content` must yield only
  the content (SSEParser already reads only `choices.0.delta.content` — lock it in).

---

## Sequencing

```
A  observability ──┬─→ B0  image 400 fix (independent, land first)
                   │
                   └─→ C1–C4  enum + wire mapping
                              ↓
                        C5  capability gating   ← must land before C6
                              ↓
                        C6  UI (model picker) → D full test suite
                                                   ↓
                              version bump 0.1.9+2018 → melos analyze → melos run test
```

Phase A and Phase B0 can ship as a standalone hotfix release — they don't depend on the
effort feature at all.

## Open questions for the user

1. Should the 1568 px long-edge cap be **fixed**, or configurable per profile? (Fixed is
   simpler and matches Anthropic's own token-cost guidance.)
2. Keep `reasoningExclude` pinned to `true` (hide thinking entirely), or expose a toggle for
   users who want to see the reasoning?
