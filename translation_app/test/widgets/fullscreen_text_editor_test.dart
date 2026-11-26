import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:translation_app/l10n/app_localizations.dart';
import 'package:translation_app/widgets/fullscreen_text_editor.dart';
import 'package:translation_app/widgets/home_input_area.dart';

class _Shell extends StatefulWidget {
  const _Shell({this.initial = 'Hello'});
  final String initial;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  late final TextEditingController controller =
      TextEditingController(text: widget.initial);
  int wordCount = 1;

  @override
  Widget build(BuildContext context) {
    return InputArea(
      controller: controller,
      imageBytes: null,
      wordCount: wordCount,
      onPickImage: () {},
      onUploadFile: () {},
      onRemoveImage: () {},
      onTextChanged: (v) {
        setState(() {
          wordCount = v.trim().isEmpty
              ? 0
              : v.trim().split(RegExp(r'\s+')).length;
        });
      },
    );
  }
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  );
}

void main() {
  group('FullscreenTextEditor', () {
    testWidgets('opens with same text', (tester) async {
      await tester.pumpWidget(_app(const _Shell()));
      await tester.pump();
      expect(find.byType(TextField, skipOffstage: false), findsOneWidget);

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      expect(find.byType(TextField, skipOffstage: false), findsNWidgets(2));
      final fsField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(FullscreenTextEditor, skipOffstage: false),
          matching: find.byType(TextField, skipOffstage: false),
        ),
      );
      expect(fsField.controller!.text, 'Hello');
    });

    testWidgets('shared controller both ways', (tester) async {
      await tester.pumpWidget(_app(const _Shell()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      final fsFinder = find.descendant(
        of: find.byType(FullscreenTextEditor, skipOffstage: false),
        matching: find.byType(TextField, skipOffstage: false),
      );
      await tester.enterText(fsFinder, 'New text');
      await tester.pump();

      final shellState = tester.state<_ShellState>(find.byType(_Shell, skipOffstage: false));
      expect(shellState.controller.text, 'New text');

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      final compact = tester.widget<TextField>(find.byType(TextField, skipOffstage: false));
      expect(compact.controller!.text, 'New text');
    });

    testWidgets('selection survives', (tester) async {
      await tester.pumpWidget(_app(const _Shell()));
      await tester.pump();
      final shellState = tester.state<_ShellState>(find.byType(_Shell, skipOffstage: false));
      shellState.controller.selection =
          const TextSelection(baseOffset: 2, extentOffset: 5);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      expect(shellState.controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 5));
    });

    testWidgets('direction mid-edit', (tester) async {
      await tester.pumpWidget(_app(const _Shell(initial: '')));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      final fsFinder = find.descendant(
        of: find.byType(FullscreenTextEditor, skipOffstage: false),
        matching: find.byType(TextField, skipOffstage: false),
      );
      await tester.enterText(fsFinder, 'مرحبا بالعالم');
      await tester.pump();

      final fsField = tester.widget<TextField>(fsFinder);
      expect(fsField.textDirection, TextDirection.rtl);
      expect(fsField.textAlign, TextAlign.right);

      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();

      final compact = tester.widget<TextField>(find.byType(TextField, skipOffstage: false));
      expect(compact.textDirection, TextDirection.rtl);
    });

    testWidgets('word count footer', (tester) async {
      await tester.pumpWidget(_app(const _Shell(initial: '')));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      final fsFinder = find.descendant(
        of: find.byType(FullscreenTextEditor, skipOffstage: false),
        matching: find.byType(TextField, skipOffstage: false),
      );
      await tester.enterText(fsFinder, 'one two three');
      await tester.pump();

      expect(find.text('3 words'), findsOneWidget);
    });

    testWidgets('keyboard inset', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
          child: _app(const _Shell(initial: 'hello')),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      expect(find.text('1 word'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('system back', (tester) async {
      await tester.pumpWidget(_app(const _Shell()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.open_in_full));
      await tester.pumpAndSettle();

      final fsFinder = find.descendant(
        of: find.byType(FullscreenTextEditor, skipOffstage: false),
        matching: find.byType(TextField, skipOffstage: false),
      );
      await tester.enterText(fsFinder, 'edited');
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final shellState = tester.state<_ShellState>(find.byType(_Shell, skipOffstage: false));
      expect(shellState.controller.text, 'edited');
      expect(find.byType(FullscreenTextEditor, skipOffstage: false), findsNothing);
    });
  });
}
