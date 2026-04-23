// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ladolce/main.dart';

void main() {
  testWidgets('App boots to login when no cached user', (WidgetTester tester) async {
    await tester.pumpWidget(const PosApp(initialUser: null));
    await tester.pumpAndSettle();

    // Should land on the login screen when no cached user is provided.
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
