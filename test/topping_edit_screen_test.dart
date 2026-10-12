import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladolce/l10n/app_localizations.dart';
import 'package:ladolce/models/topping.dart';
import 'package:ladolce/screens/topping_edit_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a grouped topping opens without an error before groups load', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ToppingEditScreen(
          topping: Topping(
            id: 3,
            name: 'Oat',
            extraPrice: 10000,
            groupId: 1,
            groupName: 'Milk',
            groupMultiple: false,
          ),
        ),
      ),
    );
    // First frame: the groups request has not answered yet.
    expect(tester.takeException(), isNull);
    expect(find.text('Milk'), findsOneWidget);
    // The request fails in tests; the topping keeps its group.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Milk'), findsOneWidget);
  });
}
