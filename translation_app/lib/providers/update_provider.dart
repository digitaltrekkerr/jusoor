import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/update_checker_service.dart';

/// Riverpod entry point for the in-app update banner.
///
/// A `FutureProvider` matches the use case: the check is fired once
/// when the Settings screen first reads it, the result is cached for
/// the rest of the app session, and re-reading (e.g. after navigating
/// away and back) does not re-hit GitHub. The underlying service
/// already collapses every failure into `UpdateInfo.none`, so UI
/// code can do `value?.hasUpdate == true` without any error branch.
final updateInfoProvider = FutureProvider<UpdateInfo>((ref) {
  return UpdateCheckerService.check();
});
