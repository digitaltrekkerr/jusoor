import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/services/update_checker_service.dart';

void main() {
  group('UpdateCheckerService.evaluateUpdate', () {
    test('CI build tag (build-<sha>) never reports an update', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': 'build-3f9c2ab1',
          'html_url': 'https://github.com/digitaltrekkerr/jusoor/releases/tag/build-3f9c2ab1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, isEmpty);
    });

    test('newer semver tag reports an update', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': '0.1.6',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '0.1.6');
    });

    test('leading v prefix is stripped', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': 'v0.1.6',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '0.1.6');
    });

    test('pre-release suffix is stripped but still newer', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': '0.1.6-rc1',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '0.1.6');
    });

    test('equal version does not report an update', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': '0.1.5',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isFalse);
    });

    test('older version does not report an update (no downgrade nag)', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': '0.1.4',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isFalse);
    });

    test('pre-release of the same version never downgrades', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '1.0.0',
        releasePayload: {
          'tag_name': '1.0.0-alpha',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isFalse);
    });

    test('garbage tag reports no update', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': 'not-a-version',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, isEmpty);
    });

    test('missing tag reports no update', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: <String, dynamic>{},
      );
      expect(info.hasUpdate, isFalse);
      expect(info.latestVersion, isEmpty);
    });

    test('apk asset url is picked from the release assets', () {
      const apkUrl =
          'https://github.com/digitaltrekkerr/jusoor/releases/download/build-1/jusoor.apk';
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.5',
        releasePayload: {
          'tag_name': '0.1.6',
          'html_url': 'https://example.com/release/1',
          'assets': [
            {'name': 'checksums.txt', 'browser_download_url': 'https://example.com/x'},
            {'name': 'jusoor.apk', 'browser_download_url': apkUrl},
          ],
        },
      );
      expect(info.hasUpdate, isTrue);
      expect(info.apkUrl, apkUrl);
    });

    test('patch-level comparison works on equal minor versions', () {
      final info = UpdateCheckerService.evaluateUpdate(
        currentVersion: '0.1.10',
        releasePayload: {
          'tag_name': '0.1.9',
          'html_url': 'https://example.com/release/1',
          'assets': <Object>[],
        },
      );
      expect(info.hasUpdate, isFalse);
    });
  });
}