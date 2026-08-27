import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Seed color shared by the overlay's light and dark themes.
///
/// Must stay in sync with the main app's seed color (`_kSeedColor` in
/// `app.dart` and `main.dart`) so the floating window recolors in lockstep
/// with the app's light/dark mode.
const Color kOverlaySeedColor = Color(0xFF4F46E5);

/// Resolves a persisted theme-mode name to a [ThemeMode].
///
/// This is the single mapping used by the floating overlay engine:
/// `'light'`/`'dark'`/`'system'` map to their enums, and anything else
/// (value absent on a fresh install, corrupted pref, unexpected IPC payload)
/// falls back to [ThemeMode.system] so the overlay tracks the device theme
/// as the safe default — the same default the main app's
/// `themeModeProvider` uses.
ThemeMode resolveThemeMode(String? rawName) {
  switch (rawName) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// The floating overlay's [MaterialApp] shell, themed live from a
/// [ValueListenable<ThemeMode>].
///
/// The overlay runs in its own Flutter engine/isolate (see
/// `TranslationOverlayService` on Android), so it cannot watch the main
/// app's Riverpod `themeModeProvider` — provider state is NOT shared across
/// engines. Instead the overlay engine feeds a [ValueNotifier] from
/// persisted prefs (at startup, on window (re)show, and on a light poll
/// timer) and from best-effort IPC pushes; this widget rebuilds the app
/// light/dark themes the moment that notifier changes, so a theme change in
/// the main app recolors the overlay immediately without a restart.
class OverlayThemeApp extends StatelessWidget {
  /// Creates an [OverlayThemeApp] that rebuilds [MaterialApp] whenever
  /// [themeMode] emits.
  const OverlayThemeApp({
    super.key,
    required this.themeMode,
    required this.child,
  });

  /// Live source of the overlay's [ThemeMode]; updates rebuild the
  /// [MaterialApp] immediately with the matching [ThemeData].
  final ValueListenable<ThemeMode> themeMode;

  /// The overlay's root content widget (`home` of the [MaterialApp]).
  final Widget child;

  static const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Builds the overlay's [ThemeData] for a given brightness, mirroring the
  /// main app's themes (same seed + Material 3) so the floating window's
  /// colors follow the app's light/dark mode.
  static ThemeData themeFor(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: kOverlaySeedColor,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeFor(Brightness.light),
          darkTheme: themeFor(Brightness.dark),
          themeMode: mode,
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: const [Locale('en', '')],
          home: child,
        );
      },
    );
  }
}