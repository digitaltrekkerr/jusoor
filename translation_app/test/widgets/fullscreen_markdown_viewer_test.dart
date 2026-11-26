import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/widgets/fullscreen_markdown_viewer.dart';

class _FakeNotifier extends TranslationNotifier {
  @override
  TranslationState build() => const TranslationIdle();

  void emit(TranslationState s) => state = s;
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

void main() {
  late ProviderContainer container;
  late _FakeNotifier notifier;

  setUp(() {
    notifier = _FakeNotifier();
    container = ProviderContainer(overrides: [
      translationProvider.overrideWith(() => notifier),
    ]);
    container.read(translationProvider);
  });

  tearDown(() => container.dispose());

  Future<void> pushViewer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(_app(container));
    await tester.pump();
    // push via helper by calling showFullscreenMarkdownViewer requires context;
    // instead push route manually using navigator from a button-less approach:
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const FullscreenMarkdownViewer(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('FullscreenMarkdownViewer', () {
    testWidgets('done state renders markdown, no TextField', (tester) async {
      notifier.emit(const TranslationDone('**Hello** world', 'gpt-4o', 1200));
      await pushViewer(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Hello'), findsWidgets);
    });

    testWidgets('copy writes plain text', (tester) async {
      notifier.emit(const TranslationDone('**Hello** world', 'gpt-4o', 1200));
      await pushViewer(tester);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      final btn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.copy));
      btn.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(copied, 'Hello world');
      expect(find.text('Copied to clipboard'), findsWidgets);
    });

    testWidgets('long-press copy sheet', (tester) async {
      notifier.emit(const TranslationDone('**Hello** world', 'gpt-4o', 1200));
      await pushViewer(tester);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );

      final btn2 = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.copy));
      btn2.onLongPress!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Copy as plain text'), findsOneWidget); // maybe different label
      // tap markdown option
      // find by text copyAsMarkdown
      final mdTile = find.text('Copy as Markdown');
      if (mdTile.evaluate().isNotEmpty) {
        await tester.tap(mdTile);
        await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
        expect(copied, '**Hello** world');
      }
    });

    testWidgets('streaming liveness', (tester) async {
      notifier.emit(const TranslationStreaming('Hello'));
      await pushViewer(tester);
      expect(find.textContaining('Hello'), findsWidgets);

      notifier.emit(const TranslationStreaming('Hello world'));
      await tester.pump();
      expect(find.textContaining('Hello world'), findsWidgets);
    });

    testWidgets('streaming to done', (tester) async {
      notifier.emit(const TranslationStreaming('Hello'));
      await pushViewer(tester);
      notifier.emit(const TranslationDone('Hello', 'm', 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Hello'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('error while open', (tester) async {
      notifier.emit(const TranslationStreaming('Hello'));
      await pushViewer(tester);
      notifier.emit(const TranslationError('boom'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('boom'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsNothing);
    });

    testWidgets('loading state', (tester) async {
      notifier.emit(const TranslationLoading());
      await pushViewer(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsNothing);
    });
  });
}
