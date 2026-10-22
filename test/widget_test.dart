import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Tes widget Flutter berhasil', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('LaporSarana'))),
      ),
    );

    expect(find.text('LaporSarana'), findsOneWidget);
  });
}
