// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amv_hotel_app/login_screen.dart';

void main() {
  testWidgets('App loads LoginScreen', (WidgetTester tester) async {
    // Build the app with LoginScreen
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoginScreen(),
      ),
    );

    // Verify that the login screen loads
    // You can add more specific expectations based on your LoginScreen UI
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
