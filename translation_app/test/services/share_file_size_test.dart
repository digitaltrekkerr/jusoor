import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/services/share_intent_handler.dart';

void main() {
  group('parseSharedFile — 50 MB ceiling', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('jusoor-share-test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('throws SharedFileTooLargeException for a file over 50 MB', () async {
      // Create a sparse 51 MB file: truncate() does not write real bytes,
      // so the test stays fast while `file.length()` reports the size the
      // guard sees.
      final file = File('${tempDir.path}/big.txt');
      final raf = await file.open(mode: FileMode.write);
      try {
        await raf.truncate(51 * 1024 * 1024);
      } finally {
        await raf.close();
      }

      final handler = ShareIntentHandler();
      final content = SharedContent(
        filePath: file.path,
        mimeType: 'text/plain',
      );

      await expectLater(
        handler.parseSharedFile(content),
        throwsA(isA<SharedFileTooLargeException>()),
      );
    });

    test('parses a small text file normally (no exception)', () async {
      final file = File('${tempDir.path}/small.txt');
      await file.writeAsString('Hello from a small file');

      final handler = ShareIntentHandler();
      final content = SharedContent(
        filePath: file.path,
        mimeType: 'text/plain',
      );

      final result = await handler.parseSharedFile(content);
      expect(result.text, 'Hello from a small file');
    });
  });

  group('kMaxSharedFileBytes constant', () {
    test('is exactly 50 MB', () {
      expect(kMaxSharedFileBytes, 50 * 1024 * 1024);
    });
  });
}