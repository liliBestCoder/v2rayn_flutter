import 'package:flutter_test/flutter_test.dart';

import 'package:v2rayn_flutter/main.dart';

void main() {
  testWidgets('LuxwapApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LuxwapApp());
    expect(find.byType(LuxwapApp), findsOneWidget);
  });
}
