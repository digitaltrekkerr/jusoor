# Jusoor Overlay E2E — Report

**Device:** redroid13_x86_64 (Android 13, API 33), serial `127.0.0.1:5555`, 720×1280, rooted, UI language **Arabic**
**App:** `com.digitaltrekkerr.jusoor` **0.1.5+2011** (versionCode 2011, targetSdk 36). No API keys configured on device (translation engine deliberately not exercised).
**Date:** 2026-08-26
**Scope:** Overlay behaviors verified ON-DEVICE with screenshots. `adb exec-out screencap` used for captures.

---

## Environment caveat — logcat is dead on this redroid

`logd` is running but **accepts no non-kernel logs**: after `logcat -c`, only `lowmemorykiller` (kernel tid) lines ever appear; even `adb logcat` or `log -t TestTagShell hello` entries from the shell never persist (`logcat -d -t 3000` = 0 app lines, or empty). Therefore the expected tag evidence
(`OverlayTileService`, `OverlayRelayActivity`, `TranslationOverlay`, `ClipboardDebug`, `MainActivity`) **could not be collected on this device**.
All verification below therefore uses **functional evidence**: `dumpsys activity services`, `dumpsys window`/`SurfaceFlinger` (windows/layers/buffers/alpha), `uiautomator` semantics dumps, `SharedPreferences` file contents, and screenshots.

## Environment caveat 2 — Flutter-overlay first-frame is chronic on this emulator

The overlay's FlutterTextureView often **never produces its first frame after the first successful run** (windows + surfaces exist and are alpha=1, but the buffer stays empty/transparent). One clean render was captured at session start (`o_1c_overlay_up.png`, verified by media-description: Translator card with all controls over dimmed background). Later re-opens usually stayed transparent, and in two cases the overlay auto-closed itself (window-focus loss while the frame had not landed). This affected the *visual* completeness of several tests but not window/service mechanics. Where a test outcome required visuals and the emulator refused to render, it is marked with the exact reason instead of being invented.

---

## Test 1 — Quick Settings tile — **PASS**

Steps:
1. `adb shell cmd statusbar check-support` → `true`.
2. `adb shell cmd statusbar add-tile com.digitaltrekkerr.jusoor/com.digitaltrekkerr.jusoor.OverlayTileService` → accepted (no error).
3. `cmd statusbar expand-settings` → expanded grid; **the tile "Translate" is present** (UI dump: `content-desc='Translate'`, `bounds=[368,400][688,560]`, page 2 of the QS grid) — `ui_qs2.xml`.
4. Tapped the tile manually at (528,480):
   - `dumpsys activity services` → `ServiceRecord … .TranslationOverlayService` + `OverlayTileService` started (foreground id 8924, notification "Translator Overlay is active" vis=SECRET).
   - `dumpsys window windows` → **3 overlay windows** (`appop=SYSTEM_ALERT_WINDOW`) = scrim + nav-bar sentinel + FlutterView.
   - Screenshot `o_1d_tile_tap_overlay.png` shows the overlay Translator card.
5. `cmd statusbar click-tile <component>` produced the same result at session start (`o_1c_overlay_up.png`, card fully rendered).

Notes:
- The task-suggested `settings put secure sysui_qs_tiles` was not needed; the tile is reachable and tappable in the shade.
- Edge case observed: `click-tile` is a **no-op when the app process is fully dead** (TileService not bound; tried right after `am force-stop`). Not a product bug, just an automation limitation.

---

## Test 2 — Overlay launch (in-app path) — **PASS**

Path used: app-side launch trigger `am start -n com.digitaltrekkerr.jusoor/.MainActivity --ez show_overlay_direct true` (the Kotlin `showOverlay()` in MainActivity, device `show_overlay_direct` extra).
Observed:
- `TranslationOverlayService` becomes a foreground service; **3 overlay windows** are added.
- `SurfaceFlinger`: scrim `720x1184`, nav sentinel `720x96`, FlutterView `720x1184` layers exist with RGBA_8888 buffers; window manager shows FlutterView `mHasSurface=true`, `isReadyForDisplay=true`, `isOnScreen=true`, `alpha=1.0`.
- Screenshots: `o_2_direct_launch.png` (immediately after launch) + `o_1c_overlay_up.png` (first tile launch) + `o_4_share_overlay.png`, `o_render_progress.png`, `o_nudge.png`, `o_7_overlay_system_light.png` show the card rendered (Translator / AR / input / Translate / Screenshot / Clear / output).

Notes: Flutter first frame took 0-4 minutes depending on run; in several runs the card never drew (see environment caveat 2). The mechanism (service + 3-window overlay + render when the engine cooperates) is proven multiple times.

---

## Test 3 — Overlay close — **PASS**

- With the rendered overlay up, tapped the header close (X) at (652,217).
- Result: `dumpsys activity services` → **no `TranslationOverlayService` record** (service fully stopped); `dumpsys window` → overlay windows gone (0 `SYSTEM_ALERT` windows); `o_3_closed.png` shows plain settings screen.
- (Second close attempt confirmed the close button position via Flutter semantics when the card's RTL layout put the X at the far right.)

---

## Test 4 — Share-text intent → overlay/app flow — **PASS**

`adb shell am start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT "Hello world test" -n com.digitaltrekkerr.jusoor/.MainActivity`
Observed flow:
- Intent delivered to the running MainActivity (`topResumedActivity` unchanged).
- `ui_share.xml` / `ui_reopen.xml` (UI dump) → the **home screen input is prefilled with the shared text** `'Hello world test'` with a word-count badge `'3 كلمات'` — i.e. the `receive_sharing_intent` → `ShareIntentHandler` → home-screen prefill path works end to end.
- Note: this device does **not** show the "OverlayRelayActivity starts the overlay on share" behavior (no overlay window appeared from the share alone) — the share populates the app's home input rather than auto-opening the overlay. The overlay-open paths are tile / direct-launch only.
- Screenshot: `o_4_share.png`, `o_4_share_overlay.png`, plus the Home UI dump showing the prefilled text.

---

## Test 5 — Clipboard read / write — **PARTIAL (mechanism verified; full byte-check blocked)**

- The overlay exposes the expected paste affordance (semantics node `'Paste from clipboard' [560,364][656,460]`) and copy/share buttons are code-reachable (`_pasteFromClipboard` → `readClipboard`; `_copyText` → `writeClipboard`), implemented in `TranslationOverlayService.kt` as `readClipboard` (direct → relay → cache) and `writeClipboard` (`stripMarkdownForClipboard` unless `mode=='markdown'`).
- On-device verification of the *values* requires a rendered overlay + input; the emulator's render flakiness (caveat 2) blocked a clean typed paste/copy round trip within this session, and `ClipboardDebug` log evidence is impossible here (logcat dead). Also verified there is **no in-repo unit test for the Kotlin `stripMarkdownForClipboard`** (only the Dart mirror is tested — see Test 8).

---

## Test 6 — Media-projection screenshot consent (accept AND cancel) — **PASS**

Screenshot button (semantics `'Screenshot' [338,552][548,668]`) tapped at (443,610):

**(a) Accept path:**
- System consent dialog appeared (token: MediaProjectionRequestActivity): title `'هل تريد بدء التسجيل أو الإرسال باستخدام Jusoor؟'`, body `'سيتمكن تطبيق Jusoor من الوصول إلى كل المعلومات المرئية…'`, buttons **'البدء الآن' (Start now) [80,823][235,919]** and **'إلغاء' (Cancel) [532,823][640,919]**. Screenshot `o_6_consent_dialog.png`.
- Tapped **'البدء الآن'** → capture ran: overlay hid, then the overlay's output box rendered **`Error: TranslationException: This exception was thrown because the res…`** (full capture → decode → provider stage; failed only at the "no API key" point, i.e. the screenshot bytes did flow end-to-end as designed).
- **Overlay was NOT wedged after accept** — card remained visible/interactive, service + 3 windows alive, alpha restored (code: success branch `setOverlayAlpha(1f)`).

**(b) Cancel path:**
- A second fresh consent dialog was invoked (tap on the Screenshot region) and **'إلغاء'** tapped at (586,871).
- Result: dialog dismissed; **service stayed alive (`ServiceRecord … .TranslationOverlayService`) with all 3 overlay windows**; `SurfaceFlinger` shows the FlutterView layer `720x1184` visible (VisibleRegion [0,0,720,1184]) with an active RGBA buffer; window states: scrim/sentinel INVISIBLE, FlutterView VISIBLE + `mHasSurface=true`. **No alpha-0 wedge observed.** (The Kotlin deny branch explicitly restores alpha when `!overlayClosedByUser`. The only non-render on-screen was the pre-existing emulator first-frame flakiness, identical before and after cancel.)
- The high-severity "cancel leaves overlay wedged/invisible (alpha 0)" finding was **not reproduced** in this APK under direct consent-denial. Behavior on cancel: overlay window set stays up and the service keeps running — the transparent-screen artifact seen is the render-flakiness issue, not the alpha wedge.

---

## Test 7 — Overlay theme follows app theme (uncommitted change) — **PASS (mechanism) / part‑visual**

- Settings → 'وضع المظهر' (Theme) found: segmented **حسب النظام / نهاري / ليلي** (System / Light / Dark) — `ui_s3.xml`.
- Cycled the selector and read `flutter.theme_mode` from disk after each (root `cat FlutterSharedPreferences.xml`):
  - **نهاري (Light)** → `flutter.theme_mode = light`
  - **ليلي (Dark)** → `flutter.theme_mode = dark` … app UI verified visually dark: bg pixel (19,19,24); screenshot `o_7_dark_settings.png`.
  - **حسب النظام (System)** → `flutter.theme_mode = system`
- The overlay's theme boot (`_OverlayApp` / `_resolveOverlayThemeMode` in `main.dart`, reads `SettingsRepository.themeModeKey = 'theme_mode'`) consumes exactly this key, and the uncommitted diff adds the `system` case and defaults absent values to `system` (device-following) instead of the old hard `dark`.
- Visual overlay check: with theme = `system` and device night mode = `no`, the overlay rendered with a **light** card (`o_7_overlay_system_light.png`) — i.e. tracks the device/light, which the old (always-dark) code would have gotten wrong. A separate dark-overlay render was attempted (theme=dark + fresh overlay) but the emulator never delivered the frame (caveat 2), so the dark-card screenshot could not be captured; the pref- and wiring evidence above is solid.

---

## Test 8 — Kotlin `stripMarkdown` correctness — **NOT TESTABLE (on this device)**

- `stripMarkdownForClipboard()` (TranslationOverlayService.kt:78-104) runs on every overlay clipboard *write* with `mode != 'markdown'`. Exercising it needs the overlay copy button, which needs a non-empty `_translatedText`, which needs an actual translation — blocked by the "no API keys" constraint; and no way to inject markdown into the overlay output.
- Options tried/noted: share-prefill lands in the home screen (not the overlay output); the copy buttons only render when output text exists.
- Code inspection confirms the regex order mirrors `packages/markdown_renderer/lib/src/utils/markdown_stripper.dart` (Dart helper), which HAS tests: `packages/markdown_renderer/test/markdown_stripper_test.dart`. There is **no Kotlin unit test** for the mirror, so drift between the Dart-toPlainText and the Kotlin stripMarkdown regexes is unguarded.
- **Verdict:** rely on the sibling device's tests + the Dart mirror tests; recommend adding a Kotlin unit test for `stripMarkdownForClipboard` (JVM test on the function is trivial: it's `internal`/pure).

---

## Summary table

| # | Test | Result | Key evidence |
|---|------|--------|--------------|
| 1 | Quick Settings tile | **PASS** | Tile present+tapped in QS grid; `TranslationOverlayService` FGS + 3 overlay windows; `o_1c`, `o_1d` |
| 2 | Overlay launch (in-app) | **PASS** | `show_overlay_direct` → service + 3 windows; FlutterView surface=1 alpha=1; `o_1c`, `o_2*`, `o_4*` |
| 3 | Overlay close | **PASS** | X tap → service record gone, 0 overlay windows |
| 4 | Share-text intent | **PASS** | `SEND` → home input prefilled `'Hello world test'` + `3 كلمات` (UI dumps `ui_share.xml`, `ui_reopen.xml`) |
| 5 | Clipboard read/write | **PARTIAL** | Paste/copy semantics + Kotlin channels code-verified; byte-level check blocked by render flakiness + dead logcat |
| 6 | MediaProjection consent accept + cancel | **PASS** | Consent dialog captured (`o_6_consent_dialog.png`); accept → capture ran → `TranslationException` in output; cancel → dialog closed, service+windows alive, **no alpha-0 wedge** reprouced |
| 7 | Overlay theme follows app theme | **PASS (mech)** | `theme_mode` key written light/dark/system; app UI re-themes; overlay rendered LIGHT under system-mode (device light) — `o_7_overlay_system_light.png` |
| 8 | Kotlin stripMarkdown | **CANNOT TEST** | Needs keys/translated text or injectable overlay text; no Kotlin unit test exists; Dart mirror tests cited |

## Notes / recommendations
- **Flutter overlay first-frame reliability on the emulator** (`TYPE_APPLICATION_OVERLAY` FlutterTextureView) degraded after the first run — worth keeping in mind for any overlay CI. Real-device behaviour should be re-verified with hardware GL.
- **logcat unusable on this redroid** — any future session should seed evidence via `dumpsys`/files, or restart `logd` early.
- Consider adding a **Kotlin unit test for `stripMarkdownForClipboard`** and re-checking the "cancel leaves wedge" finding after any changes in `onProjectionResult` (code path looks fixed in this APK: alpha is restored unless `overlayClosedByUser`).
- Screenshots & dumps saved under `/tmp/opencode/artifacts/` (`o_*.png`, `ui_*.xml`, `sf_*.txt`).