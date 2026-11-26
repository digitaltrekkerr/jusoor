import 'package:flutter/material.dart';
import 'package:translation_core/translation_core.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/widgets/input_direction_controller.dart';

/// Full-screen multi-line editor over [controller]; text and selection are the
/// same objects as the compact field, so closing never loses or moves anything.
class FullscreenTextEditor extends StatefulWidget {
  const FullscreenTextEditor({
    super.key,
    required this.controller,
    required this.direction,
    required this.title,
    required this.hintText,
  });

  final TextEditingController controller;
  final InputDirectionController direction;
  final String title;
  final String hintText;

  @override
  State<FullscreenTextEditor> createState() => _FullscreenTextEditorState();
}

class _FullscreenTextEditorState extends State<FullscreenTextEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final fallback = Directionality.maybeOf(context) ?? TextDirection.ltr;
    widget.direction.update(widget.controller.text, fallback: fallback);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.appDone,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextDirection>(
                  valueListenable: widget.direction,
                  builder: (context, dir, _) {
                    return TextField(
                      controller: widget.controller,
                      autofocus: true,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textAlignVertical: TextAlignVertical.top,
                      textDirection: dir,
                      textAlign: dir == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeWordCount(WordCounter.count(widget.controller.text)),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes [FullscreenTextEditor] as a full-screen route; returns when popped.
Future<void> showFullscreenTextEditor(
  BuildContext context, {
  required TextEditingController controller,
  required InputDirectionController direction,
  required String title,
  required String hintText,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => FullscreenTextEditor(
        controller: controller,
        direction: direction,
        title: title,
        hintText: hintText,
      ),
    ),
  );
}
