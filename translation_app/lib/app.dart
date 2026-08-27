import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/share_intent_provider.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'services/share_intent_handler.dart';

const Color _kSeedColor = Color(0xFF4F46E5);

class JusoorApp extends StatelessWidget {
  final ProviderContainer container;

  const JusoorApp({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: const _AppShell(),
    );
  }
}

class _AppShell extends ConsumerStatefulWidget {
  const _AppShell();

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  StreamSubscription<SharedContent>? _shareSub;

  @override
  void initState() {
    super.initState();
    _initShareIntent();
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _initShareIntent() async {
    final handler = ref.read(shareIntentHandlerProvider);

    final initial = await handler.init();
    if (!mounted) return;

    if (initial != null) {
      ref.read(sharedContentProvider.notifier).set(initial);
    }

    _shareSub?.cancel();
    _shareSub = handler.onSharedContent.listen((content) {
      if (!mounted) return;
      ref.read(sharedContentProvider.notifier).set(content);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use the user-selected locale override when present, otherwise let
    // MaterialApp fall back to the device's system locale.
    final selectedLocale = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      locale: selectedLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // ARB files under lib/l10n/ are the source of truth for UI strings;
      // adding a new locale requires a new ARB file plus an entry here.
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kSeedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kSeedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: const _MainNavigation(),
    );
  }
}

class _MainNavigation extends ConsumerStatefulWidget {
  const _MainNavigation();

  @override
  ConsumerState<_MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<_MainNavigation> {
  int _currentIndex = 0;

  /// Index of the History tab in the navigation destinations.
  static const int _historyTabIndex = 1;

  static const _screens = <Widget>[
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // The History screen is preloaded inside the IndexedStack, so it
          // never re-fetches when the tab is switched to. Reload it whenever
          // it becomes visible so entries saved by other flows (overlay,
          // share intent) show up without an app restart.
          if (index == _historyTabIndex) {
            ref.read(historyListProvider.notifier).refresh();
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.translate_outlined),
            selectedIcon: const Icon(Icons.translate),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.navHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}