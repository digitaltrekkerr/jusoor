import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/widgets/translated_text_scope.dart';

/// Records `MediaQuery.textScalerOf(context).scale(14)` at each probe point so
/// a test can compare text size inside and outside the translated scope.
List<double> probeScalers(WidgetTester tester, List<String> keys) {
  final values = <double>[];
  for (final key in keys) {
    final ctx = tester.element(find.byKey(ValueKey(key)));
    values.add(MediaQuery.textScalerOf(ctx).scale(14));
  }
  return values;
}

Widget probes() => Column(
      children: [
        Builder(
          key: const ValueKey('outside'),
          builder: (ctx) => const SizedBox.shrink(),
        ),
        TranslatedTextScope(
          child: Builder(
            key: const ValueKey('inside'),
            builder: (ctx) => const SizedBox.shrink(),
          ),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The notifiers push size changes to the overlay engine; the channel has
    // no handler in tests, so answer every call with null.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('x-slayer/overlay_channel'),
      (call) async => null,
    );
  });

  group('TranslatedTextScope', () {
    testWidgets('output override grows only the scoped text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolvedOutputTextSizeProvider.overrideWithValue(28),
          ],
          child: const MaterialApp(home: Scaffold(body: _ProbeHost())),
        ),
      );

      final values = probeScalers(tester, const ['outside', 'inside']);
      expect(values[0], closeTo(14, 0.001), reason: 'outside keeps 14px');
      expect(values[1], closeTo(28, 0.001), reason: 'inside uses 28px');
    });

    testWidgets('system default leaves the ambient scaler alone',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [resolvedOutputTextSizeProvider.overrideWithValue(null)],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(body: _ProbeHost()),
            ),
          ),
        ),
      );

      final values = probeScalers(tester, const ['outside', 'inside']);
      expect(values[0], closeTo(18.2, 0.001));
      expect(values[1], closeTo(18.2, 0.001), reason: 'no override applied');
    });

    testWidgets('RTL direction does not change the scoped size',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resolvedOutputTextSizeProvider.overrideWithValue(22),
          ],
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: MaterialApp(home: Scaffold(body: _ProbeHost())),
          ),
        ),
      );

      final values = probeScalers(tester, const ['outside', 'inside']);
      expect(values[0], closeTo(14, 0.001));
      expect(values[1], closeTo(22, 0.001));
    });
  });

  group('ExplicitTextSizeScope', () {
    testWidgets('null px is a no-op', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExplicitTextSizeScope(
              px: null,
              child: Builder(
                key: ValueKey('explicit'),
                builder: _explicitSink,
              ),
            ),
          ),
        ),
      );
      final ctx = tester.element(find.byKey(const ValueKey('explicit')));
      expect(MediaQuery.textScalerOf(ctx).scale(14), closeTo(14, 0.001));
    });

    testWidgets('explicit px rescales the subtree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExplicitTextSizeScope(
              px: 20,
              child: Builder(
                key: ValueKey('explicit'),
                builder: _explicitSink,
              ),
            ),
          ),
        ),
      );
      final ctx = tester.element(find.byKey(const ValueKey('explicit')));
      expect(MediaQuery.textScalerOf(ctx).scale(14), closeTo(20, 0.001));
    });
  });

  group('text size preferences', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() => container.dispose());

    test('defaults to System (null) for both settings', () {
      expect(container.read(appTextSizeProvider), isNull);
      expect(container.read(translatedTextSizeProvider), isNull);
      expect(container.read(resolvedOutputTextSizeProvider), isNull);
    });

    test('output override wins over the global size', () async {
      await container.read(appTextSizeProvider.notifier).set(18);
      expect(container.read(resolvedOutputTextSizeProvider), 18);

      await container.read(translatedTextSizeProvider.notifier).set(26);
      expect(container.read(resolvedOutputTextSizeProvider), 26);
    });

    test('values clamp on write and persist through the repository', () async {
      final repo = container.read(settingsRepositoryProvider);

      await container.read(appTextSizeProvider.notifier).set(999);
      expect(container.read(appTextSizeProvider), 40);
      expect(repo.appTextSizePx, 40);

      await container.read(translatedTextSizeProvider.notifier).set(2);
      expect(repo.translatedTextSizePx, 10);

      await container.read(appTextSizeProvider.notifier).set(null);
      expect(repo.appTextSizePx, isNull, reason: 'null removes the pref');
      expect(container.read(resolvedOutputTextSizeProvider), 10);
    });

    test('a fresh container reads the persisted values', () async {
      final prefs = await SharedPreferences.getInstance();
      await container.read(appTextSizeProvider.notifier).set(24);
      await container.read(translatedTextSizeProvider.notifier).set(30);

      final reopened = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(reopened.dispose);

      expect(reopened.read(appTextSizeProvider), 24);
      expect(reopened.read(translatedTextSizeProvider), 30);
      expect(reopened.read(resolvedOutputTextSizeProvider), 30);
    });
  });
}

/// Renders the two probe points used by [probeScalers].
class _ProbeHost extends StatelessWidget {
  const _ProbeHost();

  @override
  Widget build(BuildContext context) => probes();
}

Widget _explicitSink(BuildContext context) => const SizedBox.shrink();
