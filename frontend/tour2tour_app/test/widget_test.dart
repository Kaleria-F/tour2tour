import 'package:flutter_test/flutter_test.dart';

import 'package:tour2tour_app/main.dart';

void main() {
  testWidgets('App smoke test: bootstraps widget tree', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const Tour2TourApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
