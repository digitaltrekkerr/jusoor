import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/services/deferred_temp_file_cleanup.dart';

/// Regression tests for the H3 temp-file deletion race.
///
/// Pre-fix behavior deleted the shared `.md` file in a `finally` block the
/// moment the share sheet closed, so a receiving target (Drive, Gmail, …)
/// could grab a deleted file. These tests pin the new deferred behavior:
/// the file must still exist right after the share flow completes and only
/// disappear after the grace period.
///
/// Uses real short timers (grace is injectable) because the assertions are
/// about real file existence, which `FakeAsync` cannot drive alongside
/// `dart:io` I/O.
void main() {
  late DeferredTempFileCleanup cleanup;
  late Directory tempDir;

  /// Short grace so tests run fast; 150ms keeps margins unambiguous with
  /// real timers.
  const grace = Duration(milliseconds: 150);

  setUp(() {
    cleanup = DeferredTempFileCleanup(gracePeriod: grace);
    DeferredTempFileCleanup.instance = cleanup;
    tempDir = Directory.systemTemp.createTempSync('jusoor_cleanup_test_');
  });

  tearDown(() async {
    cleanup.cancelPending();
    DeferredTempFileCleanup.instance = DeferredTempFileCleanup();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a real file inside the test temp dir (mimicking a share flow's
  /// written `.md` output).
  File newTempFile(String name, String content) {
    final file = File('${tempDir.path}/$name');
    file.writeAsStringSync(content);
    return file;
  }

  group('DeferredTempFileCleanup.scheduleDeletion', () {
    test('file still exists right after the share flow completes', () async {
      final file = newTempFile('translation_1.md', 'output');

      cleanup.scheduleDeletion(file.path);

      // Well inside the grace period the file must still be readable.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        file.existsSync(),
        isTrue,
        reason: 'file deleted too early — pre-fix code deleted it as soon '
            'as the share sheet closed, racing the receiving target',
      );
    });

    test('file is physically deleted after the grace period elapses',
        () async {
      final file = newTempFile('translation_1.md', 'output');

      cleanup.scheduleDeletion(file.path);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(file.existsSync(), isTrue);

      await Future<void>.delayed(grace + const Duration(milliseconds: 250));
      expect(
        file.existsSync(),
        isFalse,
        reason: 'after the grace period the temp file must be gone',
      );
    });

    test('re-sharing the same path defers deletion so the current file '
        'survives', () async {
      final file = newTempFile('translation_1.md', 'first share');
      // Longer grace so the deferral window is wide enough to observe with
      // real timers.
      final slowCleanup = DeferredTempFileCleanup(
        gracePeriod: const Duration(milliseconds: 300),
      );

      slowCleanup.scheduleDeletion(file.path); // would fire at t=300
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The user shares the same record again — the file is rewritten and
      // the pending timer must be reset, not fired.
      file.writeAsStringSync('second share');
      slowCleanup.scheduleDeletion(file.path); // timer reset → t=400
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        file.existsSync(),
        isTrue,
        reason: 're-sharing the same path must cancel the first timer — '
            'the rewritten file survived past the original deadline',
      );

      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        file.existsSync(),
        isFalse,
        reason: 'after the reset grace period the re-shared file is swept',
      );
    });

    test('re-sharing cleans up the previous file without killing the '
        'current one', () async {
      final first = newTempFile('translation_1.md', 'first');
      final second = newTempFile('translation_2.md', 'second');

      cleanup.scheduleDeletion(first.path);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      cleanup.scheduleDeletion(second.path); // resets the shared timer
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        first.existsSync(),
        isTrue,
        reason: 'the previous file must stay alive until the sweep — '
            'pre-fix code deleted it as soon as its own share closed',
      );
      expect(
        second.existsSync(),
        isTrue,
        reason: 'the current file must never be deleted before its grace',
      );

      await Future<void>.delayed(grace + const Duration(milliseconds: 250));
      expect(
        first.existsSync(),
        isFalse,
        reason: 'the previous file is swept together with the latest flush',
      );
      expect(
        second.existsSync(),
        isFalse,
        reason: 'the current file is deleted once its grace elapses',
      );
    });
  });

  group('DeferredTempFileCleanup.cleanupStaleFiles', () {
    test('deletes only owned files older than the grace period', () async {
      final stale = newTempFile('translation_stale.md', 'old leftover');
      final fresh = newTempFile('jusoor_translation_fresh.md', 'fresh');
      final unrelatedMd = newTempFile('notes_other.md', 'not ours');
      final unrelatedTxt = newTempFile('notes.txt', 'not ours either');

      // Make the stale file look like a leftover from a previous session.
      await stale.setLastModified(
        DateTime.now().subtract(const Duration(hours: 1)),
      );

      await cleanup.cleanupStaleFiles(directory: tempDir);

      expect(
        stale.existsSync(),
        isFalse,
        reason: 'old owned leftover is swept at app start',
      );
      expect(
        fresh.existsSync(),
        isTrue,
        reason: 'a recently written file (possibly being read by a share '
            'target) must never be touched',
      );
      expect(
        unrelatedMd.existsSync(),
        isTrue,
        reason: 'unrelated .md files are not ours to delete',
      );
      expect(
        unrelatedTxt.existsSync(),
        isTrue,
        reason: 'non-.md files are never considered',
      );
    });
  });
}