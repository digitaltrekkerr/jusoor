# Jusoor (جسور) — Contributor Guide

Jusoor is a Flutter on-screen translation app (Android). It shows translated
subtitles over any app using a floating overlay. The repo is a
[melos](https://melos.invertase.dev) monorepo:

- `translation_app/` — the main Android application
- `packages/translation_core/` — translation engine (Gemini + OpenRouter models)
- `packages/file_handler/` — Word/PDF/epub import & export
- `packages/history/` — translation history storage
- `packages/markdown_renderer/` — markdown rendering for reference material

## Getting started

```bash
# Requires Flutter (Dart 3.10+) and melos
dart pub global activate melos
melos bootstrap

melos analyze   # static analysis across all packages
melos run test  # run all unit tests
cd translation_app && flutter build apk --release
```

## Version policy

The single source of truth for the version is `translation_app/pubspec.yaml`,
field `version: <semver>+<build>` (example: `0.1.5+2005`).

Rules for maintainers:

1. Every commit that lands on `main` MUST increment the numeric build
   component (after the `+`) by exactly `1`. The semver prefix is only
   changed by the maintainer when starting a release cycle (`0.1.6`, `1.0.0`…).
2. Always read the current value from `pubspec.yaml` before incrementing —
   never infer it from git log or CI run numbers. Build numbers are
   immutable once shipped.
3. Releases are built automatically by `.github/workflows/release.yml` on
   push to `main`: a signed APK is published as a GitHub Release named
   `jusoor` with the asset `jusoor.apk`. The release tag is synthesised
   from the commit SHA (`build-<sha>`).

Quick bump helper:

```bash
v=$(grep '^version:' translation_app/pubspec.yaml | awk -F: '{print $2}' | tr -d ' ')
name=${v%+*}; build=${v##*+}
sed -i -E "s|^version:.*|version: ${name}+$((build + 1))|" translation_app/pubspec.yaml
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). For security issues, see
[SECURITY.md](SECURITY.md) — do not open a public issue for vulnerabilities.