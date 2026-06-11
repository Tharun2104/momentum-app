import 'package:flutter_test/flutter_test.dart';

import 'package:momentum_app/main.dart';

void main() {
  testWidgets('shows backend health check screen', (tester) async {
    await tester.pumpWidget(const MomentumApp());

    expect(find.text('Momentum'), findsOneWidget);
    expect(find.text('Backend Health'), findsOneWidget);
    expect(find.text('Check Backend'), findsOneWidget);
    expect(find.text('No backend check has run yet.'), findsOneWidget);
  });
}
