import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/widgets/fullscreen_text_editor.dart';
import 'package:translation_app/widgets/image_thumbnail.dart';
import 'package:translation_app/widgets/input_direction_controller.dart';

// ── Input area ───────────────────────────────────────────────────────

class InputArea extends StatefulWidget {
  final TextEditingController controller;
  final Uint8List? imageBytes;
  final int wordCount;
  final VoidCallback onPickImage;
  final VoidCallback onUploadFile;
  final VoidCallback onRemoveImage;
  final ValueChanged<String> onTextChanged;

  const InputArea({
    super.key,
    required this.controller,
    required this.imageBytes,
    required this.wordCount,
    required this.onPickImage,
    required this.onUploadFile,
    required this.onRemoveImage,
    required this.onTextChanged,
  });

  @override
  State<InputArea> createState() => InputAreaState();
}

class InputAreaState extends State<InputArea> {
  final InputDirectionController _direction = InputDirectionController();
  bool _hasClipboardContent = false;
  Timer? _clipboardCheckTimer;
  bool _needsInitialDetection = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    // Android 14+ (API 34) shows a toast on every clipboard read, so avoid
    // periodic polling. The manual paste button is always available.
    if (!Platform.isAndroid) {
      _clipboardCheckTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkClipboard(),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_needsInitialDetection) {
      _needsInitialDetection = false;
      _direction.seed(
        widget.controller.text,
        fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _direction.dispose();
    _clipboardCheckTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final fallback = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _direction.update(widget.controller.text, fallback: fallback);
    setState(() {});
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (mounted) {
        setState(() {
          _hasClipboardContent =
              data != null && data.text != null && data.text!.isNotEmpty;
        });
      }
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!;
        final selection = widget.controller.selection;
        int start = selection.start;
        int end = selection.end;
        final textLength = widget.controller.text.length;
        if (start < 0) start = textLength;
        if (end < 0) end = textLength;
        if (start > end) {
          final temp = start;
          start = end;
          end = temp;
        }
        if (start > textLength) start = textLength;
        if (end > textLength) end = textLength;
        final newText =
            widget.controller.text.replaceRange(start, end, text);
        widget.controller.text = newText;
        widget.onTextChanged(newText);
        widget.controller.selection = TextSelection.collapsed(
          offset: start + text.length,
        );
        _direction.update(
          widget.controller.text,
          fallback: Directionality.maybeOf(context) ?? TextDirection.ltr,
        );
        await _checkClipboard();
      }
    } catch (e) {
      debugPrint('[InputArea] Paste error: $e');
    }
  }

  void _openFullscreen() {
    final l10n = AppLocalizations.of(context);
    showFullscreenTextEditor(
      context,
      controller: widget.controller,
      direction: _direction,
      title: l10n.homeInputFullscreenTitle,
      hintText: l10n.homeInputHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: 8,
          textDirection: _direction.value,
          textAlign: _direction.value == TextDirection.rtl
              ? TextAlign.right
              : TextAlign.left,
          decoration: InputDecoration(
            hintText: l10n.homeInputHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.controller.text.isEmpty && _hasClipboardContent)
                  IconButton(
                    icon: const Icon(Icons.paste, size: 18),
                    tooltip: l10n.homePasteTooltip,
                    onPressed: _pasteFromClipboard,
                  ),
                IconButton(
                  icon: const Icon(Icons.open_in_full, size: 18),
                  tooltip: l10n.homeExpandInputTooltip,
                  onPressed: _openFullscreen,
                ),
              ],
            ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          onChanged: (value) {
            widget.onTextChanged(value);
          },
        ),
        if (widget.imageBytes != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ImageThumbnail(
              imageBytes: widget.imageBytes!,
              onRemove: widget.onRemoveImage,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              l10n.homeWordCount(widget.wordCount),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            IconButton.outlined(
              icon: const Icon(Icons.image_outlined, size: 20),
              tooltip: l10n.homePickImageTooltip,
              onPressed: widget.onPickImage,
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              icon: const Icon(Icons.attach_file, size: 20),
              tooltip: l10n.homeUploadFileTooltip,
              onPressed: widget.onUploadFile,
            ),
          ],
        ),
      ],
    );
  }
}
