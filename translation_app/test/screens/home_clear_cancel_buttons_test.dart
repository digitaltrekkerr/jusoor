import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/providers/translation_provider.dart';
import 'package:translation_app/screens/home_screen.dart';

class _FakeTranslationNotifier extends TranslationNotifier {
  int clearCalls = 0;
  int cancelCalls = 0;
  bool live = false;

  @override
  TranslationState build() => const TranslationIdle();

  void setStateForTest(TranslationState value) {
    state = value;
  }

  @override
  void clearAll() {
    clearCalls++;
    state = const TranslationIdle();
  }

  @override
  void cancel() {
    cancelCalls++;
  }

  @override
  bool get hasLiveRequest => live;
}

Future<(_FakeTranslationNotifier, ProviderContainer)> _pumpHome(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fake = _FakeTranslationNotifier();
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
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return (fake, container);
}

FilledButton _translateButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.byKey(const ValueKey('home-translate-cancel-button')),
  );
}

void main() {
  group('Home clear/cancel buttons', () {
    testWidgets('idle with empty input disables translate and keeps clear enabled',
        (tester) async {
      await _pumpHome(tester);

      expect(_translateButton(tester).onPressed, isNull);
      final clearButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('home-clear-button')),
      );
      expect(clearButton.onPressed, isNotNull);
    });

    testWidgets('running with live request shows enabled cancel', (tester) async {
      final (fake, _) = await _pumpHome(tester);
      fake.live = true;
      fake.setStateForTest(const TranslationLoading());
      await tester.pump();

      final button = _translateButton(tester);
      expect(button.onPressed, isNotNull);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('running with spent token shows disabled cancel', (tester) async {
      final (fake, _) = await _pumpHome(tester);
      fake.live = false;
      fake.setStateForTest(const TranslationLoading());
      await tester.pump();

      final button = _translateButton(tester);
      expect(button.onPressed, isNull);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('home-translate-cancel-button')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(fake.cancelCalls, 0);
    });

    testWidgets('clear during run aborts and resets button state', (tester) async {
      final (fake, _) = await _pumpHome(tester);
      fake.live = true;
      fake.setStateForTest(const TranslationStreaming('partial'));

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('home-clear-button')));
      await tester.pump();

      expect(fake.clearCalls, 1);
      fake.live = false;
      fake.setStateForTest(const TranslationIdle());
      await tester.pump();

      expect(find.text('Translate'), findsOneWidget);
      expect(_translateButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('home-clear-button')));
      await tester.pump();
      expect(fake.clearCalls, 2);
    });

    testWidgets('Arabic locale smoke shows clear/cancel labels', (tester) async {
      final (fake, _) = await _pumpHome(tester, locale: const Locale('ar'));
      fake.live = true;
      fake.setStateForTest(const TranslationLoading());
      await tester.pump();

      expect(find.text('مسح'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
    });
  });
}
