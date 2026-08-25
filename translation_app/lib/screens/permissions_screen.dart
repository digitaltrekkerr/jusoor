import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Permissions screen — explains every Android permission the app requests
/// and, where applicable, offers a Grant button that surfaces the relevant
/// system dialog or settings page.
///
/// Copy kept in sync with the app's permission matrix: rows are ordered
/// from most sensitive (screen capture) to informational (Quick Settings
/// Tile).
class PermissionsScreen extends StatefulWidget {
  /// Creates the [PermissionsScreen].
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  /// The same MethodChannel used by `overlay_handlers.dart` and `main.dart`
  /// for overlay + notifications. See `MainActivity.kt` for the Kotlin
  /// side. The channel currently exposes:
  ///   * `checkOverlayPermission` (bool)
  ///   * `requestOverlayPermission` (bool)
  ///   * `requestNotificationPermission` (bool)
  /// `checkNotificationPermission` is not implemented on the Kotlin side
  /// yet, so we optimistically treat notifications as "not granted" and
  /// rely on the system dialog. The Grant button falls back to a hint
  /// snackbar for any channel method that is not implemented.
  static const MethodChannel _channel =
      MethodChannel('dev.flutter.org/overlay_permission');

  bool? _overlayGranted;
  bool _notificationsGranted = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refreshStatuses();
  }

  Future<void> _refreshStatuses() async {
    if (!Platform.isAndroid) return;
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final overlay = await _channel.invokeMethod<bool>(
        'checkOverlayPermission',
      );
      final notifications = await _channel.invokeMethod<bool>(
        'checkNotificationPermission',
      );
      if (!mounted) return;
      setState(() {
        _overlayGranted = overlay ?? false;
        _notificationsGranted = notifications ?? false;
      });
    } catch (e) {
      debugPrint('[PermissionsScreen] status check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _grantOverlay() async {
    if (!Platform.isAndroid) {
      _showFallbackSnackbar();
      return;
    }
    try {
      final ok = await _channel.invokeMethod<bool>(
        'requestOverlayPermission',
      );
      if (!mounted) return;
      if (ok == false) {
        // The user was sent to the system settings page; show a hint
        // explaining how to finish granting the permission.
        _showFallbackSnackbar();
      }
    } on MissingPluginException {
      _showFallbackSnackbar();
    } catch (e) {
      debugPrint('[PermissionsScreen] requestOverlayPermission failed: $e');
      _showFallbackSnackbar();
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _refreshStatuses();
  }

  Future<void> _grantNotifications() async {
    if (!Platform.isAndroid) {
      _showFallbackSnackbar();
      return;
    }
    try {
      final launched = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      if (!mounted) return;
      // On pre-Android-13 devices the Kotlin handler returns `false` because
      // the runtime permission does not exist; on Android 13+ it returns
      // `true` after firing the dialog.
      if (launched == true) {
        setState(() => _notificationsGranted = false);
      } else {
        _showFallbackSnackbar();
      }
    } on MissingPluginException {
      _showFallbackSnackbar();
    } catch (e) {
      debugPrint(
        '[PermissionsScreen] requestNotificationPermission failed: $e',
      );
      _showFallbackSnackbar();
    }
  }

  /// MediaProjection is granted per-session, not persistently, and the
  /// consent dialog can only be triggered from `MediaProjectionRequestActivity`
  /// (which lives inside the overlay service). From the Permissions screen
  /// the best we can do is direct the user to the app's system settings
  /// page — and if that channel method is not implemented, fall back to
  /// the hint snackbar.
  Future<void> _grantScreenCapture() async {
    if (!Platform.isAndroid) {
      _showFallbackSnackbar();
      return;
    }
    try {
      await _channel.invokeMethod('openAppSettings');
    } on MissingPluginException {
      _showFallbackSnackbar();
    } catch (e) {
      debugPrint('[PermissionsScreen] openAppSettings failed: $e');
      _showFallbackSnackbar();
    }
  }

  void _showFallbackSnackbar() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.pagesPermissionSettingsHint),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pagesPermissionsTitle),
        actions: [
          IconButton(
            tooltip:
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
            icon: const Icon(Icons.refresh),
            onPressed: _checking ? null : _refreshStatuses,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PermissionCard(
              title: l10n.pagesPermissionScreenCaptureTitle,
              body: l10n.pagesPermissionScreenCaptureBody,
              status: _ScreenCaptureStatusWidget(l10n: l10n),
              action: _GrantAction(
                label: l10n.pagesPermissionScreenCaptureGrant,
                onPressed: _grantScreenCapture,
              ),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionOverlayTitle,
              body: l10n.pagesPermissionOverlayBody,
              status: _OverlayStatusWidget(
                l10n: l10n,
                granted: _overlayGranted,
              ),
              action: _GrantAction(
                label: l10n.pagesPermissionOverlayGrant,
                onPressed: _grantOverlay,
              ),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionInternetTitle,
              body: l10n.pagesPermissionInternetBody,
              status: _InfoStatusWidget(l10n: l10n),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionClipboardTitle,
              body: l10n.pagesPermissionClipboardBody,
              status: _InfoStatusWidget(l10n: l10n),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionFgsTitle,
              body: l10n.pagesPermissionFgsBody,
              status: _InfoStatusWidget(l10n: l10n),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionNotificationsTitle,
              body: l10n.pagesPermissionNotificationsBody,
              status: _NotificationsStatusWidget(
                l10n: l10n,
                granted: _notificationsGranted,
              ),
              action: _GrantAction(
                label: l10n.pagesPermissionNotificationsGrant,
                onPressed: _grantNotifications,
              ),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionShareTitle,
              body: l10n.pagesPermissionShareBody,
              status: _InfoStatusWidget(l10n: l10n),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionQuickSettingsTitle,
              body: l10n.pagesPermissionQuickSettingsBody,
              status: _InfoStatusWidget(l10n: l10n),
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              title: l10n.pagesPermissionFilesTitle,
              body: l10n.pagesPermissionFilesBody,
              status: _InfoStatusWidget(l10n: l10n),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single permission row: title, body, status chip, optional grant button.
class _PermissionCard extends StatelessWidget {
  final String title;
  final String body;
  final Widget status;
  final Widget? action;

  const _PermissionCard({
    required this.title,
    required this.body,
    required this.status,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            status,
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status chip for the overlay (SYSTEM_ALERT_WINDOW) row.
class _OverlayStatusWidget extends StatelessWidget {
  final AppLocalizations l10n;
  final bool? granted;

  const _OverlayStatusWidget({required this.l10n, required this.granted});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (granted == true) {
      return _StatusChip(
        label: l10n.pagesPermissionStatusGranted,
        icon: Icons.check_circle_outline,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    }
    return _StatusChip(
      label: l10n.pagesPermissionStatusDenied,
      icon: Icons.info_outline,
      background: colorScheme.errorContainer,
      foreground: colorScheme.onErrorContainer,
    );
  }
}

/// Status chip for the notifications (POST_NOTIFICATIONS) row.
///
/// Reflects the live state queried through `checkNotificationPermission`
/// (Kotlin NotificationManagerCompat.areNotificationsEnabled), refreshed
/// on screen open and after a permission grant attempt.
class _NotificationsStatusWidget extends StatelessWidget {
  final AppLocalizations l10n;
  final bool granted;

  const _NotificationsStatusWidget({
    required this.l10n,
    required this.granted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (granted) {
      return _StatusChip(
        label: l10n.pagesPermissionStatusGranted,
        icon: Icons.check_circle_outline,
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    }
    return _StatusChip(
      label: l10n.pagesPermissionStatusDenied,
      icon: Icons.info_outline,
      background: colorScheme.errorContainer,
      foreground: colorScheme.onErrorContainer,
    );
  }
}

/// Status chip for screen capture — informational because MediaProjection
/// is granted per-session and has no persistent flag.
class _ScreenCaptureStatusWidget extends StatelessWidget {
  final AppLocalizations l10n;

  const _ScreenCaptureStatusWidget({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _StatusChip(
      label: l10n.pagesPermissionStatusInformational,
      icon: Icons.security,
      background: colorScheme.secondaryContainer,
      foreground: colorScheme.onSecondaryContainer,
    );
  }
}

/// Status chip for install-time / informational rows.
class _InfoStatusWidget extends StatelessWidget {
  final AppLocalizations l10n;

  const _InfoStatusWidget({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _StatusChip(
      label: l10n.pagesGrantedAtInstall,
      icon: Icons.lock_outline,
      background: colorScheme.surfaceContainerHighest,
      foreground: colorScheme.onSurfaceVariant,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Grant button. Visually distinct from the status chip.
class _GrantAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GrantAction({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label),
    );
  }
}
