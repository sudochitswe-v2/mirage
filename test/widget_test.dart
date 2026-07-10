// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mirage/main.dart';

void main() {
  testWidgets('App UI smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MirageApp());
    await tester.pumpAndSettle();

    // Verify that the title and basic UI elements exist.
    expect(find.text('Mirage'), findsOneWidget);
    expect(find.text('System State'), findsOneWidget);
    expect(find.text('/etc/os-release'), findsOneWidget);

    // Verify the buttons exist.
    expect(find.text('Restore Native OS'), findsOneWidget);
    expect(find.text('Spoof to Ubuntu'), findsOneWidget);
  });
}
