/// End-to-end integration tests for Jusoor on a live Android device.
///
/// Run with:
/// ```
/// cd translation_app && flutter test integration_test/app_test.dart -d <device_id>
/// ```
///
/// The suite boots the real app shell (`JusoorApp`) against the device's
/// real SharedPreferences (no mocks), replicating production `main()`
/// initialization (legacy migration + built-in profile/template restore).
/// No network/LLM calls are triggered.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translation_app/app.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/services/settings_repository.dart';
import 'package:translation_app/widgets/selection_modal.dart';

/// SharedPreferences key used by [AppLocaleNotifier].
const _kAppLocaleKey = 'app_locale';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  /// Boots a fresh app instance with hermetic state:
  ///  * wipes SharedPreferences,
  ///  * forces the UI to English (redroid system locale is ar-EG),
  ///  * re-runs production boot-time migration/built-in restore.
  Future<(ProviderContainer, SharedPreferences)> launchApp(
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString(_kAppLocaleKey, 'en');

    // Same non-fatal init sequence as production main().
    try {
      final repo = SettingsRepository(
        secureStorage: const FlutterSecureStorage(aOptions: AndroidOptions()),
        prefs: prefs,
      );
      await repo.migrateToProfileSystem();
      await repo.restoreBuiltInItems();
    } catch (e) {
      debugPrint('repo init failed (non-fatal): $e');
    }

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(JusoorApp(container: container));
    await settle(tester);
    return (container, prefs);
  }

  testWidgets('T1: bottom nav visible; Help & Info screens open and back',
      (tester) async {
    await launchApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'History', 'Settings']) {
      expect(navLabel(label), findsOneWidget);
    }

    await tapNav(tester, 'Settings');
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

    final cases = <String, String>{
      'Support': 'Support Jusoor',
      'Permissions': 'Permissions',
      'Instructions': 'Instructions',
    };
    for (final entry in cases.entries) {
      await scrollUntilTextVisible(tester, entry.key);
      await tester.tap(find.text(entry.key));
      await settle(tester);
      expect(
        find.widgetWithText(AppBar, entry.value),
        findsOneWidget,
        reason: 'AppBar for "${entry.key}" screen',
      );
      await tester.pageBack();
      await settle(tester);
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
    }
  });

  testWidgets('T4: target language selection updates UI and persists',
      (tester) async {
    final (container, prefs) = await launchApp(tester);

    // Default on a clean install: target = Arabic.
    expect(targetValue('Arabic'), findsOneWidget);

    // ── Target: Arabic -> French ──────────────────────────────────────
    await tester.tap(targetControl());
    await settle(tester);
    await tester.tap(_modalOption('French'));
    await settle(tester);

    expect(targetValue('French'), findsOneWidget);
    expect(container.read(targetLanguageProvider), 'French');
    // reload() round-trips through the platform plugin (real disk read).
    await prefs.reload();
    expect(prefs.getString('default_target_language'), 'French');
  });

  testWidgets('T5: template substitute-target-language toggle persists',
      (tester) async {
    await launchApp(tester);

    await tapNav(tester, 'Settings');
    await scrollUntilTextVisible(tester, 'Templates');
    await tester.tap(find.text('Templates'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Templates'), findsOneWidget);

    const templateName = 'OpenRouter Translator';
    await scrollUntilTextVisible(tester, templateName);
    await tester.tap(find.text(templateName));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Edit Template'), findsOneWidget);

    const switchTitle = 'Auto-substitute target language';
    // The editor ListView builds lazily; the switches sit below the fold
    // on this device, so scroll them into existence first.
    await scrollUntilTextVisible(tester, switchTitle);
    Finder switchTile() => find.ancestor(
          of: find.text(switchTitle),
          matching: find.byType(SwitchListTile),
        );
    expect(switchTile(), findsOneWidget);

    final initial = tester.widget<SwitchListTile>(switchTile()).value;
    await tester.tap(switchTile());
    await settle(tester);
    expect(tester.widget<SwitchListTile>(switchTile()).value, !initial);

    await scrollUntilTextVisible(tester, 'Save');
    await tester.tap(find.text('Save'));
    await settle(tester);

    // Reopen the same template: the toggled state must have been kept.
    await scrollUntilTextVisible(tester, templateName);
    await tester.tap(find.text(templateName));
    await settle(tester);
    await scrollUntilTextVisible(tester, switchTitle);
    expect(
      tester.widget<SwitchListTile>(switchTile()).value,
      !initial,
      reason: 'substituteTargetLanguage must persist after save + reopen',
    );

    // Restore the original state so the suite leaves no side effects.
    await tester.tap(switchTile());
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);
  });

  testWidgets('T6: locale flip en->ar->en without restart', (tester) async {
    final (container, prefs) = await launchApp(tester);

    await container.read(appLocaleProvider.notifier).set(const Locale('ar'));
    await settle(tester);

    expect(navLabel('الإعدادات'), findsOneWidget);
    expect(
      tester.firstWidget<Directionality>(find.byType(Directionality))
          .textDirection,
      TextDirection.rtl,
    );
    await prefs.reload();
    expect(prefs.getString(_kAppLocaleKey), 'ar');

    await container.read(appLocaleProvider.notifier).set(const Locale('en'));
    await settle(tester);

    expect(navLabel('Settings'), findsOneWidget);
    expect(
      tester.firstWidget<Directionality>(find.byType(Directionality))
          .textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('T7: permissions rows ordered by sensitivity incl Files info',
      (tester) async {
    await launchApp(tester);

    await tapNav(tester, 'Settings');
    await scrollUntilTextVisible(tester, 'Permissions');
    await tester.tap(find.text('Permissions'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Permissions'), findsOneWidget);

    const expected = <String>[
      'Screen capture (screenshot translation)',
      'Overlay (Display over other apps)',
      'Internet access',
      'Clipboard (Paste in the overlay)',
      'Background service (overlay engine)',
      'Notifications',
      'Share from other apps',
      "Quick Settings 'Translate' tile",
      'Importing files',
    ];

    // Jump back to the top of the list first.
    await advanceScrolls(tester, -6000);
    await settle(tester);

    // Walk down in small steps, recording titles in the order they are
    // encountered top-to-bottom. ListView builds lazily, so off-screen
    // rows cannot be found directly.
    final seen = <String>[];
    for (var step = 0; step < 40 && seen.length < expected.length; step++) {
      final dy = <String, double>{};
      for (final title in expected) {
        final f = find.text(title);
        if (f.evaluate().isNotEmpty) {
          dy[title] = tester.getTopLeft(f.first).dy;
        }
      }
      final visibleTitles = dy.keys.toList()
        ..sort((a, b) => dy[a]!.compareTo(dy[b]!));
      for (final t in visibleTitles) {
        if (!seen.contains(t)) seen.add(t);
      }
      if (seen.length >= expected.length) break;
      await advanceScrolls(tester, 220);
      await settle(tester);
    }

    expect(seen, expected);

    // The Files row is informational ("granted at install"), like all
    // install-time permission rows.
    expect(find.text('Granted at install'), findsWidgets);
  });

  testWidgets('T8: Settings app-language picker flips UI en->ar->en',
      (tester) async {
    final (container, prefs) = await launchApp(tester);

    await tapNav(tester, 'Settings');
    await scrollUntilTextVisible(tester, 'App Language');
    await tester.tap(find.text('App Language'));
    await settle(tester);

    // Default: launchApp forces `app_locale = en` so the UI is English.
    expect(container.read(appLocaleProvider), const Locale('en', ''));

    await tester.tap(find.text('العربية'));
    await settle(tester);

    // UI flips to Arabic live, preference persisted.
    expect(navLabel('الإعدادات'), findsOneWidget);
    expect(container.read(appLocaleProvider)?.languageCode, 'ar');
    await prefs.reload();
    expect(prefs.getString(_kAppLocaleKey), 'ar');

    // Revert from the now-Arabic Settings screen.
    await scrollUntilTextVisible(tester, 'لغة التطبيق');
    await tester.tap(find.text('لغة التطبيق'));
    await settle(tester);
    await tester.tap(find.text('English'));
    await settle(tester);

    expect(navLabel('Settings'), findsOneWidget);
    expect(container.read(appLocaleProvider), const Locale('en', ''));
  });

  testWidgets('T9: articles list page renders tiles and reader renders Markdown',
      (tester) async {
    await launchApp(tester);

    // Open Settings and scroll to the new "Articles" tile in Help & Support.
    await tapNav(tester, 'Settings');
    await scrollUntilTextVisible(tester, 'Articles');

    // The Articles tile is a regular ListTile in the section; tap it to push
    // the ArticlesScreen route. (Note: 'Articles' appears later as the
    // AppBar title of that route too, so we use the ListTile scope here.)
    await tester.tap(find.widgetWithText(ListTile, 'Articles'));
    await settle(tester);

    // On the list page: AppBar shows 'Articles' (so the text appears at least
    // twice — AppBar + every ListTile doesn't repeat it, so findsWidgets
    // means we navigated successfully to the list page).
    expect(find.text('Articles'), findsWidgets);

    // All three bundled article titles are present as ListTile rows.
    for (final title in const [
      'ما هو تطبيق جسور للترجمة الفورية على Android؟',
      'كيفية استخدام overlay الترجمة على أي تطبيق',
      'أمان وخصوصية Jusoor — لماذا يحتاج تلك الأذونات؟',
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    // Tap the first article row to push ArticleScreen.
    await tester.tap(find.text('ما هو تطبيق جسور للترجمة الفورية على Android؟'));
    await settle(tester);

    // Body-only phrase (not present in the tile title/excerpt) signals the
    // asset loaded and BiDiMarkdownView rendered the H1+paragraph.
    expect(find.textContaining('تخيّل مشهداً مألوفاً'), findsOneWidget);
  });

  testWidgets('T10: target-language search field filters and keeps usable',
      (tester) async {
    await launchApp(tester);

    await tester.tap(targetControl());
    await settle(tester);

    // The bottom sheet is open and shows the search hint and the options.
    expect(find.byType(SelectionModal<String>), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search languages...'), findsOneWidget);

    // Focus the search field: this is what triggers the modal to expand to
    // full screen. Typing afterwards exercises the search filter and proves
    // the expanded layout remains usable (no layout overflow behind the IME).
    final searchField = find.widgetWithText(TextField, 'Search languages...');
    await tester.tap(searchField);
    await settle(tester);

    await tester.enterText(searchField, 'Fren');
    await settle(tester);

    // Only French survives the filter, and the search remains inside a live
    // SelectionModal (proving the bottom sheet has not crashed).
    expect(find.text('French'), findsOneWidget);
    expect(find.text('German'), findsNothing);
    expect(find.byType(SelectionModal<String>), findsOneWidget);
  });
}

// ── Helpers ─────────────────────────────────────────────────────────────

/// pumpAndSettle with a short timeout so a stuck frame loop fails fast
/// instead of hanging for the default 10 minutes.
Future<void> settle(WidgetTester tester) =>
    tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 15));

Finder navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(navLabel(label));
  await settle(tester);
}

/// Advances every mounted [Scrollable] by [dy] logical pixels without
/// synthesizing gestures. Gesture drags are unreliable here: nested
/// scrollables (the multi-line System Prompt field in the template editor)
/// win the gesture arena and swallow the drag, starving the outer ListView.
Future<void> advanceScrolls(WidgetTester tester, double dy) async {
  final states = tester.stateList<ScrollableState>(find.byType(Scrollable));
  for (final state in states) {
    final pos = state.position;
    if (!pos.hasContentDimensions || !pos.hasPixels) continue;
    if (pos.maxScrollExtent <= pos.minScrollExtent) continue;
    final target =
        (pos.pixels + dy).clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() < 0.5) continue;
    await pos.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
}

/// Scrolls until [text] is present in the tree, then brings it fully into
/// the viewport. A bare presence check is not enough: ListView keeps
/// cache-extent children mounted below the fold where their screen area is
/// covered by the navigation bar, so taps there miss.
Future<void> scrollUntilTextVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  for (var attempt = 0; attempt < 25; attempt++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await settle(tester);
      return;
    }
    await advanceScrolls(tester, 240);
    await settle(tester);
  }
  fail('Text "$text" did not become visible after scrolling.');
}

// ── Language-selector helpers ─────────────────────────────────────────

Finder targetControl() => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == 'Target language',
    );

/// The selected-value Text of a language dropdown. The InputDecorator also
/// keeps its hint Text in the tree even when it is not painted, so value
/// finds are filtered to the value text, which sets ellipsis overflow.
Finder _dropdownValue(Finder control, String text) => find.descendant(
      of: control,
      matching: find.byWidgetPredicate(
        (w) => w is Text && w.data == text && w.overflow == TextOverflow.ellipsis,
      ),
    );

Finder targetValue(String text) => _dropdownValue(targetControl(), text);

/// The option text of the currently open language-selection bottom sheet.
Finder _modalOption(String label) => find.descendant(
      of: find.byType(SelectionModal<String>),
      matching: find.text(label),
    );
