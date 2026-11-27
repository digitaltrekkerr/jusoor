import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/utils/text_size.dart';
import 'package:translation_app/widgets/translated_text_scope.dart';

/// Settings row that opens the text-size sheet (global + translated-only).
class TextSizeSettingsTile extends ConsumerWidget {
  const TextSizeSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final global = ref.watch(appTextSizeProvider);
    final output = ref.watch(translatedTextSizeProvider);

    String subtitle;
    if (global == null && output == null) {
      subtitle = l10n.settingsTextSizeSystem;
    } else if (output == null) {
      subtitle = l10n.settingsTextSizePx(global!);
    } else {
      final left = global == null
          ? l10n.settingsTextSizeSystem
          : l10n.settingsTextSizePx(global);
      subtitle = '$left • ${l10n.settingsTextSizeOutputOnlyShort(output)}';
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.format_size),
      title: Text(l10n.settingsTextSize),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showTextSizeSheet(context),
    );
  }
}

void _showTextSizeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TextSizeSheet(),
  );
}

class _TextSizeSheet extends ConsumerStatefulWidget {
  const _TextSizeSheet();

  @override
  ConsumerState<_TextSizeSheet> createState() => _TextSizeSheetState();
}

class _TextSizeSheetState extends ConsumerState<_TextSizeSheet> {
  int? _global;
  int? _output;

  @override
  void initState() {
    super.initState();
    _global = ref.read(appTextSizeProvider);
    _output = ref.read(translatedTextSizeProvider);
  }

  void _setGlobal(int? v) {
    final c = clampTextSizePx(v);
    setState(() => _global = c);
    ref.read(appTextSizeProvider.notifier).set(c);
  }

  void _setOutput(int? v) {
    final c = clampTextSizePx(v);
    setState(() => _output = c);
    ref.read(translatedTextSizeProvider.notifier).set(c);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final screenH = MediaQuery.of(context).size.height;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: screenH * 0.9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                Text(l10n.settingsTextSizeTitle,
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(l10n.settingsTextSizeDescription,
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsTextSizeSystem),
                  subtitle: Text(l10n.settingsTextSizeSystemSubtitle),
                  value: _global == null,
                  onChanged: (on) {
                    if (on) {
                      _setGlobal(null);
                    } else {
                      _setGlobal(_global ?? 16);
                    }
                  },
                ),
                if (_global != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          min: kTextSizeMinPx.toDouble(),
                          max: kTextSizeMaxPx.toDouble(),
                          divisions: kTextSizeMaxPx - kTextSizeMinPx,
                          value: _global!.toDouble(),
                          label: '$_global px',
                          onChanged: (v) => _setGlobal(v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: _PxField(
                          value: _global!,
                          onChanged: _setGlobal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ExplicitTextSizeScope(
                    px: _global,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l10n.settingsTextSizePreview,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  ExplicitTextSizeScope(
                    px: _global,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Preview معاينة',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const Divider(),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.settingsTextSizeOutputOnly),
                        subtitle:
                            Text(l10n.settingsTextSizeOutputOnlySubtitle),
                        value: _output != null,
                        onChanged: (on) {
                          if (on) {
                            _setOutput(_output ?? _global ?? 16);
                          } else {
                            _setOutput(null);
                          }
                        },
                      ),
                      if (_output != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                min: kTextSizeMinPx.toDouble(),
                                max: kTextSizeMaxPx.toDouble(),
                                divisions: kTextSizeMaxPx - kTextSizeMinPx,
                                value: _output!.toDouble(),
                                label: '$_output px',
                                onChanged: (v) => _setOutput(v.round()),
                              ),
                            ),
                            SizedBox(
                              width: 96,
                              child: _PxField(
                                value: _output!,
                                onChanged: _setOutput,
                              ),
                            ),
                          ],
                        ),
                        Text(l10n.settingsTextSizeOutputEffective(_output!)),
                        const SizedBox(height: 4),
                        ExplicitTextSizeScope(
                          px: _output,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              l10n.settingsTextSizePreview,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: () {
                    _setGlobal(null);
                    _setOutput(null);
                  },
                  child: Text(l10n.settingsTextSizeReset),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PxField extends StatefulWidget {
  const _PxField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_PxField> createState() => _PxFieldState();
}

class _PxFieldState extends State<_PxField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toString());
    _focus = FocusNode();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _PxField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focus.hasFocus) {
      _ctrl.text = widget.value.toString();
    }
  }

  void _commit() {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) {
      _ctrl.text = widget.value.toString();
      return;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _ctrl.text = widget.value.toString();
      return;
    }
    final clamped = clampTextSizePx(parsed)!;
    _ctrl.text = clamped.toString();
    widget.onChanged(clamped);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: const InputDecoration(
        suffixText: 'px',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}