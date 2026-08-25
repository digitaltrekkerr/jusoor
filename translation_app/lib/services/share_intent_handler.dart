import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_handler/file_handler.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class SharedContent {
  final String? text;
  final String? filePath;
  final String? mimeType;
  final Uint8List? imageBytes;
  final String? imageMimeType;

  const SharedContent({
    this.text,
    this.filePath,
    this.mimeType,
    this.imageBytes,
    this.imageMimeType,
  });

  bool get hasText => text != null && text!.isNotEmpty;
  bool get hasFile => filePath != null && filePath!.isNotEmpty;
  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
}

/// Service that listens for incoming share intents (both cold-start and
/// warm-start) and emits [SharedContent] objects through a broadcast stream.
///
/// Usage:
/// ```dart
/// final handler = ShareIntentHandler();
/// final initial = await handler.init();
/// handler.onSharedContent.listen((content) { ... });
/// // ...
/// handler.dispose();
/// ```
class ShareIntentHandler {
  static const _platformChannel = MethodChannel('dev.flutter.org/share');

  StreamSubscription<List<SharedMediaFile>>? _mediaStreamSub;

  final _onSharedContentController =
      StreamController<SharedContent>.broadcast();

  /// Broadcast stream that emits [SharedContent] whenever a new share intent
  /// is received while the app is already running.
  Stream<SharedContent> get onSharedContent =>
      _onSharedContentController.stream;

  /// Initialises the stream listeners and returns any shared content that
  /// launched the app from a cold start.
  ///
  /// Returns `null` when the app was not launched via a share intent.
  Future<SharedContent?> init() async {
    // Listen for share intents arriving while the app is in memory.
    _mediaStreamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          _onSharedContentController.add(_convert(files.first));
        }
      },
      onError: (Object err) {
        // Swallow stream errors — the UI will handle missing content gracefully.
      },
    );

    // Check for a share intent that caused the app to launch (cold start).
    final List<SharedMediaFile> initialMedia = await ReceiveSharingIntent
        .instance
        .getInitialMedia();
    if (initialMedia.isNotEmpty) {
      // Prevent re-processing on subsequent calls.
      ReceiveSharingIntent.instance.reset();
      return _convert(initialMedia.first);
    }

    return null;
  }

  Future<SharedContent> parseSharedFile(SharedContent content) async {
    if (!content.hasFile) return content;

    final filePath = content.filePath!;

    // Handle content:// URIs via platform channel
    if (filePath.startsWith('content://')) {
      final bytes = await _readContentUri(filePath);
      if (bytes == null) return content;

      if (content.imageMimeType != null || _isImagePath(filePath)) {
        return SharedContent(
          filePath: content.filePath,
          mimeType: content.mimeType,
          imageBytes: bytes,
          imageMimeType: content.imageMimeType ?? 'image/jpeg',
        );
      }

      // Treat as text
      final parsed = utf8.decode(bytes, allowMalformed: true);
      return SharedContent(text: parsed, mimeType: content.mimeType);
    }

    final file = File(filePath);
    if (!await file.exists()) return content;

    if (content.imageMimeType != null || _isImagePath(filePath)) {
      final bytes = await file.readAsBytes();
      return SharedContent(
        filePath: content.filePath,
        mimeType: content.mimeType,
        imageBytes: bytes,
        imageMimeType: 'image/jpeg',
      );
    }

    final extension = filePath.split('.').last.toLowerCase();
    final rawContent = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final parsed = ParserFactory.parse(rawContent, extension);
    return SharedContent(text: parsed, mimeType: content.mimeType);
  }

  Future<Uint8List?> _readContentUri(String uri) async {
    try {
      final result = await _platformChannel.invokeMethod('readContentUri', uri);
      return result as Uint8List?;
    } catch (e) {
      return null;
    }
  }

  static SharedContent _convert(SharedMediaFile media) {
    // Content URI for text: route through parseSharedFile
    if (media.type == SharedMediaType.text &&
        media.path.startsWith('content://')) {
      return SharedContent(filePath: media.path, mimeType: media.mimeType);
    }

    if (media.type == SharedMediaType.text &&
        !media.path.startsWith('/')) {
      return SharedContent(text: media.path, mimeType: media.mimeType);
    }

    if (media.type == SharedMediaType.image) {
      final mimeType = media.mimeType ?? _mimeTypeFromPath(media.path);
      return SharedContent(
        filePath: media.path,
        mimeType: mimeType,
        imageMimeType: mimeType,
      );
    }

    return SharedContent(filePath: media.path, mimeType: media.mimeType);
  }

  static String? _mimeTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => null,
    };
  }

  static bool _isImagePath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(ext);
  }

  /// Cancels the stream subscription and closes the controller.
  void dispose() {
    _mediaStreamSub?.cancel();
    _onSharedContentController.close();
  }
}
