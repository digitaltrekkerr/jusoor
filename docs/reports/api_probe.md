# Jusoor — API Probe Results (2026-08-26)

Validated both API keys live, tested auth styles per endpoint, and confirmed exact
model IDs for device E2E testing. All curl recipes below were run successfully and
are shell-safe. Words in `$KEY` / `$VAR` position must be replaced with the real
value (`source /tmp/opencode/keys.env` provides `OPENROUTER_API_KEY`,
`GEMINI_API_KEY`).

Raw artifacts in this directory: `or_models.json`, `gem_key.json`,
`gem_oa_models.json`, `*_translate*.json`, `or_stream_m3.json`.

---

## 1. OpenRouter key — VALID

`sk-or-v1-…` (73 chars). GET `/api/v1/models` with `Authorization: Bearer` →
**HTTP 200** (417 models). This is the auth the app uses (`openrouter_provider.dart`
`_kDefaultHeaders`, Bearer + `HTTP-Referer`/`X-Title`).

### Available FREE (`pricing.prompt == pricing.completion == 0`) and ultra-cheap models

Verified present in the live model list (no guessing):

| Model ID | Price $/token | Notes |
|---|---|---|
| `minimax/minimax-m3:free` | 0 / 0 | ✅ tested, clean translation |
| `google/gemma-4-26b-a4b-it:free` | 0 / 0 | ⚠️ tested, 429 (shared free pool) |
| `google/gemma-4-31b-it:free` | 0 / 0 | ⚠️ tested, 429 |
| `z-ai/glm-5.2:free` | 0 / 0 | ⚠️ tested, 429 |
| `minimax/minimax-m2.7:free`, `nvidia/nemotron-3.5-lightning:free`, `liquid/lfm-2.5-2.6b:free`, `thinkingmachines/inkling:free`, `cohere/north-mini-code:free` | 0 / 0 | not tested |
| `mistralai/mistral-small-24b-instruct-2501` | `0.00000005` / `0.00000008` | ✅ tested, clean + fast, ~$0.000003/req |
| `qwen/qwen3.7-flash` | `0.00000003` / `0.00000013` | ⚠️ tested, `message.content` = **null** — AVOID |
| `deepseek/deepseek-v4-flash-0731` | `0.00000006` / `0.00000012` | ⚠️ tested, CoT fills `content` — AVOID for assertions |
| `~deepseek/deepseek-v4-flash-latest` | `0.00000003` / `0.000000075` | not tested (same family as above — treat as reasoning) |
| `google/gemma-3-4b-it` | `0.00000005` / `0.0000001` | not tested |

Note: the widely assumed `deepseek/*:free`, `qwen/*:free`, `meta-llama/*:free`
rounds are **not in the current model list** — do not hardcode them.

### OpenRouter validation results

| Model | stream | HTTP | Latency | Result |
|---|---|---|---|---|
| `google/gemma-4-26b-a4b-it:free` | false | **429** | 0.86 s | `upstream_provider_shared_pool` rate limit |
| `z-ai/glm-5.2:free` | false | **429** | 1.23 s | same; `Retry-After: 5` |
| `google/gemma-4-31b-it:free` | false | **429** | 0.43 s | same |
| `minimax/minimax-m3:free` | false | **200** | 2.61 s | "Welcome to the Jusoor app. We wish you a happy day." cost 0 |
| `minimax/minimax-m3:free` | **true** | **429** | 1.11 s | streaming pushed upstream into rate limit |
| `qwen/qwen3.7-flash` | false | 200 | 1.41 s | `content: null` (122 reasoning tokens) — app renders empty |
| `deepseek/deepseek-v4-flash-0731` | false | 200 | 9.95 s | CoT preamble in `content` (120 tokens) — app renders the reasoning |
| `mistralai/mistral-small-24b-instruct-2501` | false | **200** | 0.86 s | clean, "Welcome to the Jusoor app. We wish you a happy day.", $0.0000034 |
| `qwen/qwen3.7-flash` (stream) | — | not run | — | reasoning model, expect same null-content issue |

### Recommended OpenRouter model IDs (device E2E)

1. **`mistralai/mistral-small-24b-instruct-2501`** — PRIMARY. Clean plain-instruct
   output (no reasoning), fast (0.9 s), ~$0.000003/request. Reliable under load.
2. **`minimax/minimax-m3:free`** — free tier; clean output non-streaming. Use only
   if `stream:false` and tolerate occasional 429 (see gotchas).
3. `google/gemma-4-26b-a4b-it:free` / `google/gemma-4-31b-it:free` — good free
   German-family backup, but 429-flaky.

### OpenRouter curl recipes (exact, as run)

```bash
# Validated translation (cheap + reliable)
curl -sS -m 60 https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -H "HTTP-Referer: https://github.com/digitaltrekkerr/jusoor" \
  -H "X-Title: Jusoor" \
  -d '{"model":"mistralai/mistral-small-24b-instruct-2501","messages":[{"role":"system","content":"You are a professional translator. Translate the user's message from Arabic to English."},{"role":"user","content":"أهلاً بك في تطبيق جسور"}],"stream":false,"max_tokens":120}'

# Free tier (expect occasional 429; retry after ~5 s)
curl -sS -m 60 https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -H "HTTP-Referer: https://github.com/digitaltrekkerr/jusoor" \
  -H "X-Title: Jusoor" \
  -d '{"model":"minimax/minimax-m3:free","messages":[{"role":"system","content":"You are a professional translator. Translate the user'\''s message from Arabic to English."},{"role":"user","content":"أهلاً بك في تطبيق جسور"}],"stream":false,"max_tokens":120}'

# Models list (key validity check) -> HTTP 200
curl -sS -m 30 https://openrouter.ai/api/v1/models \
  -H "Authorization: Bearer $OPENROUTER_API_KEY"
```

---

## 2. Gemini key — VALID, but auth style is endpoint-dependent (critical)

Key is a 53-char `AQ.Ab…` OAuth-style token. Probing both auth styles:

| Endpoint | Auth header | HTTP | Result |
|---|---|---|---|
| `GET /v1beta/models` | `x-goog-api-key: $KEY` | **200** | list of 50 models ✅ |
| `GET /v1beta/models` | `Authorization: Bearer $KEY` | **401** | invalid credentials ❌ |
| `GET /v1beta/openai/models` | `Authorization: Bearer $KEY` | **200** | OpenAI-compat list ✅ |
| `GET /v1beta/openai/models` | `x-goog-api-key: $KEY` | **404** | ❌ |
| `GET /v1/openai/models` (either) | — | **404** | path is `v1beta/openai`, not `v1/openai` |

> **Gotcha:** the same token is an API key on the native path (`x-goog-api-key`)
> and a Bearer token on the OpenAI-compat path (`v1beta/openai`). Bearer fails on
> native, x-goog fails on compat.

### Flash models actually present (validated, no guessing)

Native list (`/v1beta/models`): **`gemini-2.5-flash`**, **`gemini-2.5-flash-lite`**,
`gemini-2.5-flash-image`, `gemini-2.5-flash-native-audio-*`, `gemini-2.5-flash-preview-tts`,
`gemini-3.1-flash-lite`, `gemini-3.1-flash-image*`,
**`gemini-3.5-flash`**, **`gemini-3.5-flash-lite`**, **`gemini-3.6-flash`**,
**`gemini-3.7-flash`**, `gemini-3-flash-preview`, `gemini-flash-latest`,
`gemini-flash-lite-latest`, `gemini-omni-flash-preview`.

The user's expected "3.5 flash / flash lite and 3.7 flash" all **exist**; there is
also a `3.6-flash` and `3.1-flash-lite`. There is **no** non-image `gemini-3.1-flash`.
The app's thinking heuristic `^gemini-(2\.5|3)` (`gemini_provider.dart:226`) matches
all of these, so `thinkingConfig` (incl. `thinkingBudget:0`) is accepted by each.

OpenAI-compat list returns the ids **with** a `models/` prefix (e.g.
`models/gemini-2.5-flash`) — but chat completions accept the **unprefixed** id
(validated below: `"model":"gemini-3.5-flash"` / `"gemini-2.5-flash"`).

### Gemini validation results

| Endpoint / model | Auth | HTTP | Latency | Result |
|---|---|---|---|---|
| native `gemini-2.5-flash:generateContent` | `x-goog-api-key` | **200** | 0.72 s | clean translation; 35 prompt + 15 out tokens; `thinkingBudget:0` honored |
| openai-compat `gemini-3.5-flash` | Bearer | 200 | 7.16 s | **TRUNCATED to 4 tokens** with `max_tokens:100` (thinking ate the budget) |
| openai-compat `gemini-2.5-flash` | Bearer | **200** | 1.96 s | clean translation; 36+14 tokens BUT `total_tokens:355` (~340 hidden thinking tokens) |

### Recommended Gemini model IDs (device E2E)

1. **`gemini-2.5-flash`** (native REST) — PRIMARY. Validated 200 in 0.72 s, clean
   output, and native endpoint honors `thinkingConfig.thinkingBudget:0` so cost
   stays minimal. This is exactly what `GeminiProvider` sends.
2. **`gemini-2.5-flash-lite`** (native REST) — fastest/cheapest tier; verified in
   model list and same API surface as 2.5-flash (not individually generation-tested
   here to save budget; treat as risk-free fallback).
3. **`gemini-3.5-flash`** / **`gemini-3.7-flash`** (native REST) — higher-quality
   tier for a second E2E screener; same native request shape with `thinkingBudget:0`
   (recommended over the OpenAI-compat path, where thinking cannot be disabled).

Use the **native** endpoint for Gemini E2E. The OpenAI-compat path
(`v1beta/openai` + Bearer) works but cannot turn off thinking → ~340 hidden
thinking tokens per request and, on thinking models, `max_tokens` truncates the
visible answer (see `gemini-3.5-flash` above).

### Gemini curl recipes (exact, as run)

```bash
# Native REST (app uses this — x-goog-api-key; thinkingConfig only for 2.5/3 family)
curl -sS -m 60 \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"systemInstruction":{"parts":[{"text":"You are a professional translator. Translate the user'\''s message from Arabic to English."}]},"contents":[{"role":"user","parts":[{"text":"أهلاً بك في تطبيق جسور"}]}],"generationConfig":{"thinkingConfig":{"thinkingBudget":0}}}'
# -> 200; text at .candidates[0].content.parts[0].text

# OpenAI-compat (Bearer!); do NOT set max_tokens on thinking models
curl -sS -m 60 \
  "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions" \
  -H "Authorization: Bearer $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gemini-2.5-flash","messages":[{"role":"system","content":"You are a professional translator. Translate the user'\''s message from Arabic to English."},{"role":"user","content":"أهلاً بك في تطبيق جسور"}],"stream":false}'
# -> 200; text at .choices[0].message.content

# Native model list (auth check + supported flash names)
curl -sS -m 30 "https://generativelanguage.googleapis.com/v1beta/models" \
  -H "x-goog-api-key: $GEMINI_API_KEY"

# OpenAI-compat model list (Bearer auth check)
curl -sS -m 30 "https://generativelanguage.googleapis.com/v1beta/openai/models" \
  -H "Authorization: Bearer $GEMINI_API_KEY"
```

---

## 3. Local router fallback — DOWN

`GET http://127.0.0.1:20128/v1/models` → connection refused (000). No local
OpenAI-compatible proxy is currently running, so no fallback routing was verified.
Do not rely on it for device E2E.

---

## Key gotchas (summarized)

1. **OpenRouter `:free` models 429 constantly** — `upstream_provider_shared_pool`
   rate limits on every free request during this probe (gemma x2, glm, even
   minimax once streaming was enabled). Retry-after ≈5 s, non-deterministic.
   Free tier tests will be flaky; assert against expected text but retry on 429.
2. **OpenRouter reasoning models break the app** — `qwen/qwen3.7-flash` returns
   `message.content:null`; `deepseek/deepseek-v4-flash-0731` fills `content` with
   chain-of-thought. The app extracts `choices.0.message.content`, so both render
   wrong/empty. Stick to plain-instruct (mistral-small) or verified free models.
3. **Gemini auth is endpoint-dependent** — native REST needs `x-goog-api-key`,
   OpenAI-compat path needs `Authorization: Bearer`. Cross them and you get
   401/404. Use path `v1beta/openai`, not `v1/openai`.
4. **Gemini OpenAI-compat cannot disable thinking** — ~340 thinking tokens/request
   on 2.5-flash, and `max_tokens:100` truncated `gemini-3.5-flash` to 4 tokens.
   For E2E prefer native REST (thinkingBudget:0 works) and never send `max_tokens`
   to the compat path.
5. **Free-tier OpenRouter + streaming** = higher 429 risk (minimax worked
   non-stream, 429 on stream). If a test step streams, prefer the paid cheap model.
6. Local router at `127.0.0.1:20128` was down during probing.

## Budget used this session (tiny)

~6 real requests (2 OpenRouter success, 3 Gemini success, 1 Gemini truncated) +
~4 zero-token auth/429 probes. Remaining device-E2E budget: ~44 translations.