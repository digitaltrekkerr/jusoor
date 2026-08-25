import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translation_app/providers/settings_provider.dart';
import 'package:translation_app/app.dart';

void main() {
  testWidgets('App renders bottom navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(JusoorApp(container: container));

    // Pump enough frames for the async settings load to complete and the
    // bottom navigation to render. Using pump() avoids a timeout from the
    // CircularProgressIndicator shown while settings are loading.
    await tester.pump(const Duration(seconds: 2));

    // Verify bottom navigation tabs are present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
