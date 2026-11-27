import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/widgets/text_size_settings_tile.dart';

/// The Settings row must start on System, then let the user pick a px size and
/// a separate px size for the translated output only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('x-slayer/overlay_channel'),
      (call) async => null,
    );
  });

  tearDown(() => container.dispose());

  Widget host() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TextSizeSettingsTile()),
        ),
      );

  testWidgets('System is the default and the sheet opens from the row',
      (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('System'), findsWidgets);
    expect(container.read(appTextSizeProvider), isNull);

    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();

    expect(find.text('Text size'), findsWidgets);
    expect(find.text('Follow the device text size'), findsWidgets);
  });

  testWidgets('turning System off sets a px size and shows the slider',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(container.read(appTextSizeProvider), 16);
    expect(find.byType(Slider), findsOneWidget);
    expect(container.read(translatedTextSizeProvider), isNull,
        reason: 'the output-only size stays on inherit');
  });

  testWidgets('the nested switch sets an output-only size', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();

    expect(container.read(translatedTextSizeProvider), isNotNull);
    expect(container.read(translatedTextSizeProvider),
        container.read(appTextSizeProvider),
        reason: 'seeded from the global size');
    expect(container.read(resolvedOutputTextSizeProvider),
        container.read(translatedTextSizeProvider));
  });

  testWidgets('reset returns both settings to System', (tester) async {
    await container.read(appTextSizeProvider.notifier).set(24);
    await container.read(translatedTextSizeProvider.notifier).set(30);

    await tester.pumpWidget(host());
    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset to system'));
    await tester.pumpAndSettle();

    expect(container.read(appTextSizeProvider), isNull);
    expect(container.read(translatedTextSizeProvider), isNull);
  });
}
