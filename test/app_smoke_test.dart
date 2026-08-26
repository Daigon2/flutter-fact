import 'package:fact_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App startet und zeigt die Startroute', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FactApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Splash'), findsOneWidget);
  });
}
