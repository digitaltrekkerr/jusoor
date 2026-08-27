import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Result of a "is there a newer release?" check against GitHub.
///
/// Returned by [UpdateCheckerService.check]. All failures (network,
/// missing fields, malformed tag) are folded into a `hasUpdate: false`
/// result so the calling UI can simply not render the banner without
/// needing its own error handling.
class UpdateInfo {
  /// True when the latest GitHub release is strictly newer than the
  /// running app version. Pre-releases and equal versions both return
  /// `false` so we never nag users to "downgrade".
  final bool hasUpdate;

  /// Latest release tag with the leading `v` stripped (e.g. `0.1.6`).
  /// Empty string when unknown.
  final String latestVersion;

  /// Human-facing URL of the release notes page on GitHub.
  final String releaseUrl;

  /// Direct download URL of the APK for the device's ABI (e.g.
  /// `jusoor-arm64-v8a.apk`), or `null` when the release did not upload
  /// one (e.g. a draft or a release created manually without the workflow).
  final String? apkUrl;

  /// Markdown body of the release. Optional; only used for the future
  /// "what's new" expansion in the banner.
  final String? body;

  /// Creates an [UpdateInfo].
  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.releaseUrl,
    this.apkUrl,
    this.body,
  });

  /// Empty result used as the safe default for any failure path.
  const UpdateInfo.none()
    : hasUpdate = false,
      latestVersion = '',
      releaseUrl = '',
      apkUrl = null,
      body = null;
}

/// Checks GitHub Releases for a newer Jusoor version.
///
/// The check is intentionally a single GET against the public
/// `releases/latest` endpoint. No API key, no proxy, no caching layer:
/// the endpoint is rate-limited per IP, a 5-second timeout is short
/// enough that a hung request never blocks the Settings screen, and
/// every error path collapses to [UpdateInfo.none] so the UI never
/// has to know whether the check ran at all.
///
/// CI TAG POLICY — WHY `build-<sha>` TAGS ARE IGNORED (deliberate, not a
/// bug): the repo's release workflow publishes a GitHub Release tagged
/// `build-<sha>` for EVERY commit that lands on `main`. Those tags are
/// synthesized per-commit CI artifacts, not real releases. This service
/// intentionally ignores any tag that is not a genuine semver release
/// (see [_normalizeVersion]), so the "update available" banner only ever
/// appears for real semver releases published by the maintainer. Do not
/// change this behavior.
class UpdateCheckerService {
  /// GitHub repository (`owner/name`) that hosts Jusoor's releases.
  /// Update here if the project is ever moved.
  static const String _repo = 'digitaltrekkerr/jusoor';

  /// Public Releases API endpoint for the latest published release.
  static final Uri _latestReleaseUri = Uri.parse(
    'https://api.github.com/repos/$_repo/releases/latest',
  );

  /// Per-request timeout. Kept short on purpose: a flaky network must
  /// never freeze the Settings screen, and GitHub's CDN responds in
  /// well under a second from any healthy connection.
  static const Duration _requestTimeout = Duration(seconds: 5);

  /// User-Agent required by the GitHub API; anonymous UAs get a
  /// 403 from some endpoints.
  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'Jusoor-Android-UpdateChecker',
  };

  /// Returns the latest release info, or [UpdateInfo.none] on any
  /// failure (network error, parse error, missing fields).
  ///
  /// Never throws. Callers can blindly render the banner when
  /// [UpdateInfo.hasUpdate] is `true` and do nothing otherwise.
  static Future<UpdateInfo> check() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = _normalizeVersion(packageInfo.version);

      final preferredAbi = await _readPreferredAbi();

      final response = await http
          .get(_latestReleaseUri, headers: _headers)
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          '[UpdateChecker] GitHub returned ${response.statusCode}; '
          'assuming no update.',
        );
        return UpdateInfo.none();
      }

      final Map<String, dynamic> payload = jsonDecode(response.body)
          as Map<String, dynamic>;

      return evaluateUpdate(
        currentVersion: currentVersion,
        releasePayload: payload,
        preferredAbi: preferredAbi,
      );
    } on TimeoutException {
      debugPrint('[UpdateChecker] Request timed out; assuming no update.');
      return UpdateInfo.none();
    } catch (e) {
      // Any other failure (no network, malformed JSON, missing
      // platform channel for package_info, …) — fold to "no update".
      debugPrint('[UpdateChecker] Check failed: $e');
      return UpdateInfo.none();
    }
  }

  /// Reads the device ABI list from the platform channel so the update
  /// checker can pick the matching split-per-abi artifact.
  ///
  /// Returns `null` on any failure (channel missing, platform unsupported)
  /// — the caller then falls back to the first APK asset it finds.
  static Future<String?> _readPreferredAbi() async {
    try {
      const channel = MethodChannel('dev.flutter.org/overlay_permission');
      final abis = await channel.invokeListMethod<String>('getSupportedAbis');
      if (abis == null || abis.isEmpty) return null;
      return abis.first;
    } catch (e) {
      debugPrint('[UpdateChecker] Could not read ABI: $e');
      return null;
    }
  }

  /// Pure evaluation of a GitHub release payload against the running
  /// version — no HTTP, no platform channels, so it can be unit-tested
  /// directly. Never throws.
  ///
  /// Returns [UpdateInfo.none] when the release tag is missing or is
  /// not a semver tag at all (e.g. CI artifacts tagged `build-<sha>`),
  /// so an automated build tag can never produce a fake "update
  /// available" banner.
  static UpdateInfo evaluateUpdate({
    required String currentVersion,
    required Map<String, dynamic> releasePayload,
    String? preferredAbi,
  }) {
    final rawTag = releasePayload['tag_name'] as String?;
    if (rawTag == null || rawTag.isEmpty) {
      return UpdateInfo.none();
    }
    final latestVersion = _normalizeVersion(rawTag);
    if (latestVersion.isEmpty) {
      return UpdateInfo.none();
    }

    final releaseUrl = (releasePayload['html_url'] as String?) ?? '';
    final body = releasePayload['body'] as String?;

    // Find the APK asset for this device's ABI. The release workflow
    // uploads three split-per-abi artifacts — `jusoor-arm64-v8a.apk`,
    // `jusoor-armeabi-v7a.apk`, `jusoor-x86_64.apk` — so we match the
    // device ABI when known and otherwise pick the first `.apk` asset.
    String? apkUrl;
    final assets = releasePayload['assets'];
    if (assets is List) {
      // Normalize the preferred ABI to the artifact naming: the platform
      // reports e.g. `arm64-v8a`, matching `jusoor-arm64-v8a.apk`.
      final abiSuffix = preferredAbi == null ? null : 'jusoor-$preferredAbi.apk';
      for (final raw in assets) {
        if (raw is! Map) continue;
        final name = raw['name'] as String? ?? '';
        final lower = name.toLowerCase();
        if (!lower.endsWith('.apk')) continue;
        // Prefer an exact ABI match when one is advertised.
        if (abiSuffix != null && lower.endsWith(abiSuffix)) {
          apkUrl = raw['browser_download_url'] as String?;
          break;
        }
        apkUrl ??= raw['browser_download_url'] as String?;
      }
    }

    final hasUpdate = _isNewer(latestVersion, currentVersion);

    return UpdateInfo(
      hasUpdate: hasUpdate,
      latestVersion: latestVersion,
      releaseUrl: releaseUrl,
      apkUrl: apkUrl,
      body: body,
    );
  }

  /// Strips a leading `v` and any pre-release suffix (`-rc1`,
  /// `-beta.2`, …) so we only compare stable semver-like components.
  ///
  /// Returns `''` when [raw] is not a version-like tag at all (e.g.
  /// CI tags such as `build-<sha>`), so callers land on their
  /// "no update" path instead of comparing gibberish.
  ///
  /// Examples:
  ///   `v0.1.6`     → `0.1.6`
  ///   `0.1.6`      → `0.1.6`
  ///   `v1.0.0-rc1` → `1.0.0`  (pre-release ignored — never downgrade)
  ///   `build-abc1` → `''`     (CI build tag — not a version)
  static String _normalizeVersion(String raw) {
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final dash = v.indexOf('-');
    if (dash >= 0) v = v.substring(0, dash);
    // Must look like a semver tag (`N.N` or `N.N.N`). Anything else
    // — e.g. the CI workflow's `build-<sha>` release tags — is not a
    // version and must not be compared.
    if (!_semverTag.hasMatch(v)) return '';
    return v;
  }

  /// Matches `N.N` or `N.N.N` (no `v` prefix, no pre-release suffix).
  static final RegExp _semverTag = RegExp(r'^\d+(\.\d+){1,2}$');

  /// Returns true when [latest] is strictly newer than [current] under
  /// a major.minor.patch comparison. Missing components are treated
  /// as `0`. Anything unparseable counts as "no update" so we never
  /// nag users based on gibberish.
  static bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    if (l == null || c == null) {
      debugPrint(
        '[UpdateChecker] Unparseable version(s) "$latest" / '
        '"$current"; assuming no update.',
      );
      return false;
    }
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  /// Parses `a.b.c` into a 3-int list, padding short versions with
  /// zeros. Returns `null` if any component is not an integer.
  static List<int>? _parse(String v) {
    final parts = v.split('.');
    if (parts.length > 3) return null;
    final out = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      out.add(n);
    }
    while (out.length < 3) {
      out.add(0);
    }
    return out;
  }
}
