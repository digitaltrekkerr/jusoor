import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/screens/home_screen.dart';
import 'package:translation_app/widgets/bidi_markdown_view.dart';
import 'package:translation_app/widgets/fullscreen_markdown_viewer.dart';

class _FakeTranslationNotifier extends TranslationNotifier {
  @override
  TranslationState build() => const TranslationIdle();
  void emit(TranslationState s) => state = s;
}

Future<(_FakeTranslationNotifier, ProviderContainer)> _pumpHome(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  TranslationState initialState = const TranslationIdle(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fake = _FakeTranslationNotifier();
  if (initialState is! TranslationIdle) {
    // initialize then emit
  }
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      translationProvider.overrideWith(() => fake),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
  if (initialState is! TranslationIdle) {
    container.read(translationProvider);
    fake.emit(initialState);
    await tester.pump();
  }
  return (fake, container);
}

void main() {
  group('home screen expand', () {
    testWidgets('paste + expand buttons', (tester) async {
      // clipboard has content
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': 'pasted'};
          }
          return null;
        },
      );

      await _pumpHome(tester);
      // paste button shown when empty
      expect(find.byIcon(Icons.paste), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsWidgets);

      // type text
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();
      // paste button hidden, expand still shown
      expect(find.byIcon(Icons.paste), findsNothing);
      expect(find.byIcon(Icons.open_in_full), findsWidgets);

      // image + attach buttons and word count label
      expect(find.byIcon(Icons.image_outlined), findsWidgets);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.textContaining('word'), findsWidgets);
    });

    testWidgets('expand pushes TextField and returns', (tester) async {
      await _pumpHome(tester);
      await tester.tap(find.byIcon(Icons.open_in_full).first);
      await tester.pumpAndSettle();
      expect(find.byType(TextField, skipOffstage: false), findsNWidgets(2));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('output expand pushes viewer', (tester) async {
      await _pumpHome(tester, initialState: const TranslationDone('**Hello** world', 'gpt-4o', 1200));
      // find output expand icon (second open_in_full maybe)
      final expandIcons = find.byIcon(Icons.open_in_full);
      // tap last (output) expand button
      await tester.tap(expandIcons.last);
      await tester.pumpAndSettle();
      expect(find.byType(FullscreenMarkdownViewer), findsOneWidget);
      expect(find.byType(BiDiMarkdownView, skipOffstage: false), findsWidgets);
    });

    testWidgets('rtl smoke', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': 'pasted'};
          }
          return null;
        },
      );
      await _pumpHome(tester, locale: const Locale('ar'));
      final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
      // tooltip resolves to Arabic string
      final iconBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.open_in_full).first);
      expect(iconBtn.tooltip, l10n.homeExpandInputTooltip);
      expect(tester.takeException(), isNull);
    });
  });
}
