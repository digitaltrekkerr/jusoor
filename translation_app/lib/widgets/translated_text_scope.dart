import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/utils/text_size.dart';

/// Applies the translated-text size (output override, else global, else
/// system) to its subtree. ConsumerWidget: only used inside the app's
/// [ProviderScope].
class TranslatedTextScope extends ConsumerWidget {
  const TranslatedTextScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final px = ref.watch(resolvedOutputTextSizeProvider);
    if (px == null) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: resolveTextScaler(
          px: px,
          basePx: bodyBaseFontPx(Theme.of(context).textTheme),
          system: mq.textScaler,
        ),
      ),
      child: child,
    );
  }
}

/// Same effect as [TranslatedTextScope] but with an explicit resolved px
/// (used by the overlay engine, which has no Riverpod container).
class ExplicitTextSizeScope extends StatelessWidget {
  const ExplicitTextSizeScope({super.key, required this.px, required this.child});

  final int? px;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final clamped = clampTextSizePx(px);
    if (clamped == null) return child;
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: resolveTextScaler(
          px: clamped,
          basePx: bodyBaseFontPx(Theme.of(context).textTheme),
          system: mq.textScaler,
        ),
      ),
      child: child,
    );
  }
}