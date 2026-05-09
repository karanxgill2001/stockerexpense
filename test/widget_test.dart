// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:stocker/main.dart';

void main() {
  testWidgets('shows login screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('admin credentials open dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), 'admin');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Stock Movement'), findsOneWidget);
  });

  testWidgets('invalid credentials show error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField).at(0), 'wrong');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    expect(
      find.text('Invalid login ID or password. Use admin / admin.'),
      findsOneWidget,
    );
  });
}
