import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dbt_app/data/persistence_service.dart';
import 'package:dbt_app/main.dart';
import 'package:dbt_app/screens/favorites_screen.dart';
import 'package:dbt_app/screens/splash_screen.dart';
import 'package:dbt_app/state/app_state.dart';
import 'package:dbt_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows splash screen on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const DbtApp());
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.image(const AssetImage(SplashScreen.assetPath)),
      findsOneWidget,
    );
  });

  Future<void> pumpFavorites(WidgetTester tester, AppState appState) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const FavoritesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(FavoritesScreen));
      await Future.wait([
        for (final asset in [
          'assets/images/intensity_123.png',
          'assets/images/intensity_456.png',
          'assets/images/intensity_78.png',
          'assets/images/intensity_910.png',
        ])
          precacheImage(AssetImage(asset), context),
      ]);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('favorites popups use the modern dialog shell', (tester) async {
    final appState = AppState(PersistenceService());
    await appState.load();

    await pumpFavorites(tester, appState);

    await tester.tap(find.text('Additional resources: click here'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency'), findsOneWidget);
    expect(find.text('Crisis Text Line'), findsOneWidget);
    expect(find.text('Trevor Project'), findsOneWidget);
    expect(find.text('Call 911'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add contact'));
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('favorites list filters by selected intensity', (tester) async {
    final appState = AppState(PersistenceService());
    await appState.load();
    await appState.toggleFavorite(exerciseId: 'cold_shock', intensity: 9);
    await appState.toggleFavorite(
      exerciseId: 'label_what_you_notice',
      intensity: 2,
    );

    await pumpFavorites(tester, appState);

    expect(
      find.text('Choose an intensity to see your saved exercises.'),
      findsOneWidget,
    );
    expect(find.text('Cold Shock'), findsNothing);
    expect(find.text('Label What You Notice'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<int>(9)));
    await tester.pump();

    expect(find.text('Cold Shock'), findsOneWidget);
    expect(find.text('Label What You Notice'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<int>(1)));
    await tester.pump();

    expect(find.text('Cold Shock'), findsNothing);
    expect(find.text('Label What You Notice'), findsOneWidget);
  });
}
