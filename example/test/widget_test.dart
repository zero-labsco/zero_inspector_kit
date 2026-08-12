// Example app widget test.
//
// Verifies that the HomePage builds and shows its app bar title.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zero_inspector_kit_example/main.dart';

void main() {
  testWidgets('ExampleHomePage shows app bar title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ExampleHomePage()));

    expect(find.text('Zero Inspector Kit Example'), findsOneWidget);
  });
}
