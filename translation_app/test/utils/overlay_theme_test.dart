import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:translation_app/utils/overlay_theme.dart';

void main() {
  group('resolveThemeMode', () {
    test('maps light to ThemeMode.light', () {
      expect(resolveThemeMode('light'), ThemeMode.light);
    });

    test('maps dark to ThemeMode.dark', () {
      expect(resolveThemeMode('dark'), ThemeMode.dark);
    });

    test('maps system to ThemeMode.system and keeps system tracking', () {
      expect(resolveThemeMode('system'), ThemeMode.system);
    });

    test('defaults to system for an absent pref (fresh install)', () {
      expect(resolveThemeMode(null), ThemeMode.system);
    });

    test('defaults to system for an unrecognized value', () {
      expect(resolveThemeMode('neon'), ThemeMode.system);
      expect(resolveThemeMode(''), ThemeMode.system);
    });
  });

  group('OverlayThemeApp — live re-theme without restart', () {
    testWidgets(
      'MaterialApp.themeMode and rendered ThemeData follow the '
      'ValueNotifier as it changes',
      (tester) async {
        final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
        addTearDown(themeMode.dispose);

        await tester.pumpWidget(
          OverlayThemeApp(
            themeMode: themeMode,
            // Keyed probe so Theme.of reads a point inside the MaterialApp.
            child: const SizedBox(
              key: ValueKey('overlay-probe'),
            ),
          ),
        );

        MaterialApp app() =>
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        ThemeData themeAtProbe() => Theme.of(
              tester.element(find.byKey(const ValueKey('overlay-probe'))),
            );

        // Initial state: system (device) — light platform in tests — and no
        // restart needed for the transitions that follow.
        expect(app().themeMode, ThemeMode.system);
        expect(themeAtProbe().brightness, Brightness.light);

        themeMode.value = ThemeMode.dark;
        // MaterialApp animates theme changes (AnimatedTheme, ~200ms), so
        // settle past the animation before asserting the rendered ThemeData.
        await tester.pumpAndSettle();
        expect(app().themeMode, ThemeMode.dark);
        expect(themeAtProbe().brightness, Brightness.dark);

        themeMode.value = ThemeMode.light;
        await tester.pumpAndSettle();
        expect(app().themeMode, ThemeMode.light);
        expect(themeAtProbe().brightness, Brightness.light);

        // Back to system tracking.
        themeMode.value = ThemeMode.system;
        await tester.pumpAndSettle();
        expect(app().themeMode, ThemeMode.system);
        expect(themeAtProbe().brightness, Brightness.light);
      },
    );

    testWidgets('overlay themes mirror the main app seed and Material 3', (
      tester,
    ) async {
      final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
      addTearDown(themeMode.dispose);

      await tester.pumpWidget(
        OverlayThemeApp(
          themeMode: themeMode,
          child: const SizedBox(key: ValueKey('overlay-probe')),
        ),
      );

      final theme = Theme.of(
        tester.element(find.byKey(const ValueKey('overlay-probe'))),
      );
      expect(theme.useMaterial3, isTrue);
      // Same seed as the main app, so the overlay recolors in lockstep.
      expect(
        theme.colorScheme.primary,
        ColorScheme.fromSeed(
          seedColor: kOverlaySeedColor,
          brightness: Brightness.light,
        ).primary,
      );
    });
  });
}