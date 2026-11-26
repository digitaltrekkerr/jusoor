import 'package:flutter/material.dart';

import 'package:translation_app/l10n/app_localizations.dart';

// ── Action buttons ───────────────────────────────────────────────────

class ActionButtons extends StatelessWidget {
  final bool isRunning;
  final bool canCancel;
  final bool canTranslate;
  final bool canClear;
  final VoidCallback onTranslate;
  final VoidCallback onCancel;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final bool canShare;

  const ActionButtons({
    super.key,
    required this.isRunning,
    required this.canCancel,
    required this.canTranslate,
    required this.canClear,
    required this.onTranslate,
    required this.onCancel,
    required this.onClear,
    required this.onShare,
    required this.canShare,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clearButton = OutlinedButton.icon(
      key: const ValueKey('home-clear-button'),
      onPressed: canClear ? onClear : null,
      icon: const Icon(Icons.clear, size: 18),
      label: Text(l10n.homeClearButton),
    );
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('home-translate-cancel-button'),
            onPressed: isRunning
                ? (canCancel ? onCancel : null)
                : (canTranslate ? onTranslate : null),
            icon: isRunning
                ? const Icon(Icons.close)
                : const Icon(Icons.translate),
            label: Text(
              isRunning ? l10n.appCancel : l10n.homeTranslateButton,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isRunning)
          Tooltip(message: l10n.homeClearTooltip, child: clearButton)
        else
          clearButton,
        if (canShare) ...[
          const SizedBox(width: 8),
          IconButton.outlined(
            icon: const Icon(Icons.share),
            tooltip: l10n.homeShareTooltip,
            onPressed: onShare,
          ),
        ],
      ],
    );
  }
}
