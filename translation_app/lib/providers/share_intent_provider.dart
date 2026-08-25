import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/share_intent_handler.dart';

/// Provides the [ShareIntentHandler] singleton.
///
/// The handler is created once and disposed automatically when the last
/// listener is removed.
final shareIntentHandlerProvider = Provider<ShareIntentHandler>((ref) {
  final handler = ShareIntentHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

/// Notifier that holds the current [SharedContent] received from another app.
///
/// Set to `null` when no shared content is pending. The [HomeScreen] watches
/// this provider to pre-fill the input field.
class SharedContentNotifier extends Notifier<SharedContent?> {
  @override
  SharedContent? build() => null;

  /// Updates the current shared content.
  void set(SharedContent? content) => state = content;

  /// Clears the current shared content (sets it back to `null`).
  void clear() => state = null;
}

/// Provider that holds the current shared content (if any).
final sharedContentProvider =
    NotifierProvider<SharedContentNotifier, SharedContent?>(
      SharedContentNotifier.new,
    );
