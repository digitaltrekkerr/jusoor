# Contributing to Jusoor

Thanks for your interest in contributing! Jusoor is an on-device translation
overlay for Android built with Flutter. This monorepo uses
[melos](https://melos.invertase.dev) to manage the app plus its packages.

## Welcome

- Start with the root [`README.md`](README.md) for an overview and
  [`translation_app/README.md`](translation_app/README.md) for app details.
- Good first contributions: bug fixes, tests, docs, and localization (the app
  ships English + Arabic ARB files under `translation_app/lib/l10n/`).
- Please be respectful and constructive. By participating you agree to follow
  the [Contributor Covenant](https://www.contributor-covenant.org/) code of
  conduct.

## Dev Setup

Prerequisites: Flutter SDK (stable channel), JDK 17, and an Android SDK with
a supported device/emulator.

```bash
dart pub global activate melos
melos bootstrap   # links all packages and fetches dependencies
```

## Branching & Commit Style

- Branch names: `feat/*`, `fix/*`, `chore/*`.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, ...).
- Keep changes focused; add or update tests with every feature or fix.

## Running Tests

```bash
melos analyze     # static analysis (must be clean)
melos run test    # unit tests across all packages
```

Integration/E2E tests live in `integration_test/` and need a connected
Android device:

```bash
cd translation_app && flutter test ../integration_test
```

Tip: if you have no physical device, [redroid](https://github.com/remote-android/redroid-doc)
(Android-in-Docker) works well as a headless target for these tests.

## Pull Request Checklist

Before opening a PR, please make sure that:

- [ ] `melos analyze` passes with no issues.
- [ ] `melos run test` (and relevant integration tests) pass locally.
- [ ] New user-facing strings are added to **both** `app_en.arb` and `app_ar.arb`.
- [ ] No secrets, API keys, or personal data are committed; no stray
      `print`/debug logging is left behind.
- [ ] The PR description explains what changed and why.

For security-sensitive reports, do **not** open a public issue — see
[`SECURITY.md`](SECURITY.md).
