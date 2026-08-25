# translation_app

The Flutter application package of **Jusoor** (جسور) — an AI translation app
for Android with a floating overlay that translates above other apps.

Holds the UI (screens/widgets), l10n (AR/EN), Riverpod providers, and Android
overlay integration. Shared logic lives in [`packages/`](../packages/):
`translation_core`, `file_handler`, `history`, `markdown_renderer`.

See the [root README](../README.md) for features, permissions, setup, and
build instructions.

```bash
melos bootstrap   # from repo root (one-time workspace link)
flutter run       # from this directory, device/emulator connected
```
