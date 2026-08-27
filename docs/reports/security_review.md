# Jusoor — Android Security Review

Date: 2026-08-26 · Scope: `translation_app/` + `packages/{translation_core,history,file_handler,markdown_renderer}`
Reviewer: automated static audit (read-only; no files modified)

---

## Executive summary

Jusoor is in generally **good security shape** for a BYO-key translation app:
API keys are stored in Keystore-backed secure storage, dynamic receivers are
`NOT_EXPORTED`, backups explicitly exclude the sensitive databases, all default
endpoints are HTTPS, and no real secrets exist in the repo or its git history (4
commits checked). The notable exposure is the **exported launcher Activity being
usable as an "overlay trigger"** by any third-party app, plus a **markdown
link-scheme gap** in the external-link handler. Both are fixable in a few lines
and are worth addressing before a wider release. Everything else is hardening.

---

## Severity-ranked findings

### F1 — Exported `MainActivity` + `show_overlay_direct` extra ⇒ any app can force the translation overlay on top of whatever the user is doing

**Files**
- `translation_app/android/app/src/main/AndroidManifest.xml:16-73` — `MainActivity` is `android:exported="true"` with 6 `SEND` intent-filters (`text/plain`, `text/html`, `text/markdown`, `text/x-markdown`, `application/octet-stream`, `image/*`).
- `translation_app/android/app/src/main/kotlin/.../MainActivity.kt:105-120` — `handleIntent()` reads `intent.getBooleanExtra("show_overlay_direct", false)` and, if true, calls `showOverlay()` (starts `TranslationOverlayService`, which draws a full-width translucent scrim + focus-capable overlay).

**Mechanism / exploitation scenario**
`startActivity()` extras do **not** need to match any declared intent-filter. Because the activity is exported, any third-party app can `adb shell am start -n com.digitaltrekkerr.jusoor/.MainActivity --ez show_overlay_direct true` or, on-device, send `Intent().setComponent(...).putExtra("show_overlay_direct", true)` (or a plain `ACTION_SEND text/plain` — the SEND filters let other apps target it without a package-visibility grant, and it becomes a one-tap target once the user has shared to Jusoor before). This also holds over the SEND filters: no filter is required for explicit intents.

Impact, when the victim has granted the app overlay permission (the whole point of the app):
1. **Overlay spoofing / phishing-adjacent**: the overlay appears over a banking/social app with a dark scrim across the whole screen. The overlay shows attacker-chosen "shared" text (the attacker includes it in the same SEND intent), and the rendered translation content is chosen by the attacker via the source text.
2. **DoS / annoyance**: the overlay can be force-shown repeatedly (the service is `START_STICKY`), disrupting whatever the user is doing.
3. When the overlay is set `focusable`, it requests touch/keyboard focus — enabling keyboard-interception confusion in the overlay UI.

Not exploitable to *read* data (overlay content is app-rendered), but it is the most realistic third-party abuse path in the app.

**Suggested fix**
- Remove the `show_overlay_direct` branch from `handleIntent()` entirely. Per the in-code comment (`MainActivity.kt:112-117`), the corresponding Dart entrypoint `checkShowOverlayDirect` is already dead, and the Quick Settings Tile path goes through `OverlayRelayActivity` — so nothing internal depends on it.
- Also add a per-second engine-side guard: only start `TranslationOverlayService` when the *user* tapped the tile or an in-app button, never purely from an incoming intent's extras.

---

### F2 — Markdown/article links: `http(s)` confirmed, but every other scheme launches with no confirmation and no allowlist

**Files**
- `packages/markdown_renderer/lib/src/widgets/markdown_view_helpers.dart:13-28` — `handleMarkdownLinkTap`.
- Used by both renderers: `packages/markdown_renderer/lib/src/widgets/markdown_view.dart:63` and `translation_app/lib/widgets/bidi_markdown_view.dart:175`.

**Mechanism**
The confirmation dialog (`_confirmExternalLink`) is only shown when `uri.isScheme('http') || uri.isScheme('https')`. Everything else — `mailto:`, `tel:`, and *any custom scheme* — goes straight to `launchUrl(uri, mode: LaunchMode.externalApplication)` (after `canLaunchUrl`). The `<queries>` block in the manifest (doc comment lines 120-146) declares visibility for `https/http/tel/mailto` VIEW, so those resolve; unlisted custom schemes usually return `false` from `canLaunchUrl` today, but this depends on which apps are installed and on the scheme name (`intent:` is not in the list, yet a crafted `intent://https://...#Intent;...` can still mime through Chrome, which then fires an embedded Android Intent into exported components of *other* apps with attacker-controlled extras).

**Exploitation scenario**
A reference article imported/translated by the user contains `[click](intent://target/#Intent;scheme=...;...)` or a deep link `somebank-app://pay?to=attacker`. When the user taps it, no confirmation is shown, and the markdown rendered from *untrusted third-party content* (the app's core use case is translating arbitrary screen content) becomes a vector to launch external apps (`activity injection` style) without so much as a "Open external link?" prompt.

**Suggested fix**
- Allowlist to `https`/`http` only for launchability. For any other scheme, do **not** launch: show a dialog ("Link can't be opened safely") or copy the URL to clipboard.
- Keep the confirmation dialog for `http(s)` (already present). Consider also showing the full href (not just host) in the dialog.

---

### F3 — Broad `SEND` MIME filters + full-buffer read ⇒ memory-pressure DoS from an oversized share

**Files**
- `AndroidManifest.xml:38-72` (`SEND` filters include `application/octet-stream` and `image/*`).
- `translation_app/lib/providers.../share_intent_handler.dart:83-133` — `parseSharedFile` reads the whole object into a `Uint8List`; images also `base64Encode` into a single string (`home_screen.dart:88`).
- `MainActivity.kt:302-327` — `readContentUri` → `openInputStream(...).readBytes()` (no size cap).

**Mechanism / exploitation**
Any app can share a multi-GB file to Jusoor; the app slurps the entire payload into memory (`readBytes()` / `readAsBytes()` / `base64Encode`). On low-end devices this can OOM-kill Jusoor or the foreground app; repeatedly sharing large files makes it a cheap recurring DoS. Not data exposure, but noisy.

**Suggested fix**
- Cap accepted size (e.g. reject > ~50 MB with a message), check `contentResolver.getSize()`/`File.length()` *before* opening streams, and stream-process text rather than `readBytes`.

---

### F4 — Release builds silently fall back to the **debug keystore** when `key.properties` is absent

**Files**
- `translation_app/android/app/build.gradle.kts` (signing block, `hasReleaseKeystore` fallback path).

**Mechanism**
A maintainer building locally without `android/key.properties` gets a release APK signed with the Android **debug** key. CI has a fail-closed guard (`.github/workflows/release.yml:64-76`), and `key.properties` is correctly untracked (gitignored). But nothing stops a manual `gh release create` of a locally-built debug-signed APK (there is even a committed-looking `translation_app/jusoor.apk` artifact in the worktree — untracked/ignored, but easy to `--force`-add).

**Suggested fix**
- Make the debug fallback **hard-fail** for the `release` build type (throw) instead of the current `logger.warn`, or at minimum stamp the version so a debug-signed build is visibly unshippable (e.g. `versionName ...-debug`).
- Document the manual-release step to verify `apksigner verify --print-certs` shows the release key before publishing.

---

### F5 — Translation history is stored **in plaintext at rest** (backup is excluded, but the DB itself is unencrypted)

**Files**
- `packages/history/lib/src/database/app_database.dart:77-92` — `translation_history.db` stores full `input_text`/`output_text` of every translation, unencrypted SQLite.

**Context**
The `data_extraction_rules.xml` / `backup_rules.xml` correctly exclude the DB from cloud backup and device transfer (good). The residual risk is on-device: anyone with root, or an attacker able to read `/data/data/.../databases/` via a compromised device or the **MediaProjection/overlay** channel, sees the user's full translation corpus (credit-card numbers, OTPs, chat history — everything the user translates).

**Suggested fix**
- Encrypt the DB (SQLCipher) — or, lighter-weight, add an in-app setting to clear history on copy/screen-lock, and a "delete all history" button. At minimum state the at-rest risk in the settings/privacy surface.

---

### (Info) — Privacy note: full-screen MediaProjection uploads go to the user's chosen LLM

**Files**
- `TranslationOverlayService.kt:575-726` (full-screen capture), `translation_app/lib/main.dart:764-811` (screenshot → base64 → API).

By design the app uploads a full screenshot of whatever is on screen (with the overlay hidden first — `setOverlayAlpha(0f)` before capture, which is correct) to a third-party LLM provider. Acceptable for the product, but should be surfaced to the user: (a) the capture happens whenever the overlay requests it, not just on explicit "capture this" taps, and (b) provider terms/pinning are the user's responsibility. Worth adding a one-time "screenshots of the current screen are sent to your API provider" disclosure.

---

## Good-practice items (verified)

1. **API keys never leave Keystore-backed storage**
   - `settings_repository.dart:293-315` — values in `FlutterSecureStorage` (`api_key_<id>`), only IDs/names in SharedPreferences.
   - Not logged: no `debugPrint`/`Log` of key *values* anywhere (`api_keys_screen.dart` shows only a 3+4-char mask; providers pass keys only as `x-goog-api-key`/`Authorization` headers).
   - The overlay engine (separate Flutter engine) reads keys from the **same** secure storage (`overlay_utils.dart:13,52-64`) — same-process trust boundary, no cross-process handoff.
2. **Backups correctly locked down**: `allowBackup="true"` but `fullBackupContent`/`dataExtractionRules` exclude `database`, `FlutterSharedPreferences.xml`, and `FlutterSecureStorage.xml` for both cloud-backup and device-transfer (`backup_rules.xml`, `data_extraction_rules.xml`). (Optional hardening: `allowBackup="false"` + `android:hasFragileUserData="true"`.)
3. **`exported` flags are correct everywhere except the intentional F1**: `TranslationOverlayService` and both `OverlayRelayActivity`/`MediaProjectionRequestActivity` are `exported="false"`; `OverlayTileService` is `exported="true"` but protected by `android.permission.BIND_QUICK_SETTINGS_TILE` (required by the platform — correct). No ContentProviders, no exported BroadcastReceivers, **no AccessibilityService** (overlay uses `SYSTEM_ALERT_WINDOW` + MediaProjection instead — good).
4. **Intent-injection resistant component internals**: all dynamic receivers registered with `RECEIVER_NOT_EXPORTED` (`TranslationOverlayService.kt:215-334`), result broadcasts scoped with `setPackage(packageName)` (`OverlayRelayActivity.kt:106-110`, `MediaProjectionRequestActivity.kt:34-39`), and the MediaProjection grant token travels only inside the app.
5. **Networking is HTTPS-only by default, no compiled-in secrets**: Gemini `https://generativelanguage.googleapis.com` (`gemini_provider.dart:14`), OpenRouter `https://openrouter.ai/...` (`openrouter_provider.dart:14,121`), OpenAI-compatible defaults to `https://api.openai.com/v1` (`settings_repository.dart:590`), update checks hit `https://api.github.com/...` (`update_checker_service.dart:68-70`). `targetSdk 36` ⇒ Android's default cleartext-block applies (no `usesCleartextTraffic`/`networkSecurityConfig` anywhere — secure by default). No `QUERY_ALL_PACKAGES`; package visibility is scoped by `<queries>`.
6. **No real secrets in the repo or git history**: key-value grep across working tree and all 4 commits found no `AIza…`, `sk-or…`, `AQ.Ab…`, PEM keys or keystore passwords — only *variable names* (`keyPassword`/`storePassword`) inside `build.gradle.kts`. `.env*` is gitignored; `key.properties` is untracked; CI signing material is injected via GitHub `secrets.JUSOOR_*`.
7. **Prompt-injection resilience**: built-in system prompts explicitly instruct the model to treat user text as content, not instructions (`settings_repository.dart:148-151, 191-192`) — good practice for a tool that translates arbitrary attacker-influenced text.
8. **Clipboard hygiene**: clipboard text passed to the app is kept in a process-static cache that is cleared in `onDestroy` (`MainActivity.kt:26-28,59-65`) and only length (not content) is ever logged.
9. **file_handler has no path traversal / dangerous writes**: reads only come from user-picked files or share-grant scoped content URIs; exports go to `getTemporaryDirectory()` and are handed to the share sheet (`main.dart:507-518`, `home_screen.dart:354-391`) — no writes outside app sandbox, no use of the raw filename for paths.

---

## On-device / pen-test checklist (needs a real device)

These can't be fully validated statically:

1. **F1 live test**: build a 3-line malicious app (`am start` or a `PROCESS_TEXT`/`SEND` intent) that fires `show_overlay_direct=true` at Jusoor and confirm the scrim+overlay appears over an unrelated foreground app. Verify the scramble: does the overlay object to the OS mid-session and does the victim notice the scrim? (Confirms DoS/spoof severity.)
2. **Overlay focus/keyboard**: with the overlay set focusable, check that the OS IME appears over *another app*'s window and can be driven by an attacker-triggered overlay (keyboard confusion).
3. **MediaProjection consent reuse**: grant capture once, close the overlay, reopen it — on Android 14+ verify the system re-prompts for consent and that a stale projection token cannot be replayed from a freshly-started service. Confirm the screen-capture indicator remains visible.
4. **Clipboard relay flow**: on Android 10+ verify the `OverlayRelayActivity` clipboard read works and that the copied content is *not* left in the notification shade / recents (activity is `excludeFromRecents`, translucent, but confirm).
5. **F2 live**: import a markdown file containing an `intent://` link and a custom-scheme deep link; tap and observe that no confirmation dialog appears and an external activity can be launched.
6. **Backup extraction**: `adb backup` / device-transfer a profile to confirm `FlutterSecureStorage.xml`, `FlutterSharedPreferences.xml`, and `translation_history.db` are actually absent from the archive on both Android 11 and 12+ devices.
7. **F3 memory test**: share a ~1–2 GB file to the app and watch for OOM / ANR.
8. **Rooted/ADB check**: confirm DB and secure-storage files under `/data/data/...` are inaccessible without root and that the secure storage ciphertext is present but the Keystore material is not extractable.
9. **Cleartext behavior**: point a custom profile at `http://<lan-ip>/v1` (e.g. local Ollama) and confirm the request is refused by the default cleartext policy — and that this failure is surfaced to the user rather than silently retried.

---

*No files were modified during this review.*