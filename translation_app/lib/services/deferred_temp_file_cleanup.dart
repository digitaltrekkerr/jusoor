import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

/// Deletes temporary shared `.md` files on a delayed schedule instead of
/// immediately after the share sheet closes.
///
/// # Why this exists
///
/// The share flows write a translation to a temp file, hand the path to the
/// Android share sheet (a `content://` FileProvider URI), and — in the buggy
/// version — deleted the file in a `finally` block the moment the sheet
/// closed. A receiving target (Drive, Gmail, Telegram, …) can still be
/// reading the file at that moment, so the file was sometimes gone before
/// the target finished: a race / lost-file bug.
///
/// This class replaces the immediate delete with a grace period (default
/// 45 s, well beyond the lifetime of a share-sheet hand-off). Files are
/// scheduled when handed to the share sheet and physically deleted only
/// when the grace timer fires. Sharing again:
///
/// * with the **same** path — the pending timer is reset, deferring the
///   deletion so the freshly rewritten file gets its own full grace period;
/// * with a **different** path — both paths stay pending and are deleted
///   when the timer eventually fires, so the previous file is still cleaned
///   up while the current one is never deleted before its grace elapses.
///
/// All three share flows (home screen, history detail, overlay) share the
/// single [instance].
class DeferredTempFileCleanup {
  /// Builds a cleanup manager.
  ///
  /// [gracePeriod] is injectable so tests can use short delays; production
  /// call sites use the shared [instance] with the default.
  DeferredTempFileCleanup({
    this.gracePeriod = _kDefaultGracePeriod,
  });

  static const Duration _kDefaultGracePeriod = Duration(seconds: 45);

  /// Names of the temp files the app's share flows write. Startup cleanup
  /// scans for these prefixes only, so unrelated temp files are untouched.
  static const List<String> _ownedPrefixes = [
    'translation_',
    'jusoor_translation_',
  ];

  /// App-wide cleanup manager used by every share flow.
  ///
  /// Mutable so tests can swap in a short-grace instance; production code
  /// never reassigns it.
  static DeferredTempFileCleanup instance = DeferredTempFileCleanup();

  /// How long a shared temp file is kept after its share sheet completes.
  final Duration gracePeriod;

  /// Paths awaiting deletion. A single timer serves the whole set: a new
  /// share restarts it, so earlier files are swept with the newest one.
  final Set<String> _pendingPaths = {};

  Timer? _timer;

  /// Schedules [path] for physical deletion after [gracePeriod].
  ///
  /// Re-scheduling the same path (or any path) resets the timer, which is
  /// exactly the "cancel/defer" behavior required to keep a file alive
  /// while its share sheet is open. Safe to call for files that never got
  /// created — the flush re-checks existence.
  void scheduleDeletion(String path) {
    _pendingPaths.add(path);
    _timer?.cancel();
    _timer = Timer(gracePeriod, () {
      unawaited(_flush());
    });
  }

  /// Deletes every pending path, then forgets them.
  ///
  /// Paths re-added meanwhile (a re-share landing while the flush is in
  /// flight) are skipped — their new schedule owns the deletion.
  Future<void> _flush() async {
    final pending = _pendingPaths.toList();
    _pendingPaths.clear();
    _timer = null;
    for (final path in pending) {
      if (_pendingPaths.contains(path)) {
        continue;
      }
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[DeferredTempFileCleanup] Failed to delete $path: $e');
      }
    }
  }

  /// Sweeps leftover owned temp files, e.g. at app start.
  ///
  /// Only files whose modified time is older than [gracePeriod] are
  /// deleted, so a file produced seconds ago by a share sheet that is
  /// still open is never touched. [directory] defaults to the app temp
  /// directory and is injectable for tests.
  Future<void> cleanupStaleFiles({Directory? directory}) async {
    final dir = directory ?? await getTemporaryDirectory();
    try {
      if (!await dir.exists()) {
        return;
      }
      await for (final entity in dir.list()) {
        if (entity is! File || !DeferredTempFileCleanup._isOwnedName(entity)) {
          continue;
        }
        try {
          final stat = await entity.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age > gracePeriod) {
            await entity.delete();
          }
        } catch (e) {
          debugPrint(
            '[DeferredTempFileCleanup] Failed to sweep '
            '${entity.path}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('[DeferredTempFileCleanup] Sweep failed: $e');
    }
  }

  /// Cancels a pending deletion timer without deleting anything.
  ///
  /// Used by tests on teardown so a scheduled flush cannot fire after the
  /// test finished.
  void cancelPending() {
    _timer?.cancel();
    _timer = null;
  }

  static bool _isOwnedName(File file) {
    final name = file.uri.pathSegments.isEmpty
        ? file.path
        : file.uri.pathSegments.last;
    return name.endsWith('.md') &&
        _ownedPrefixes.any(name.startsWith);
  }
}