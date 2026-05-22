import 'package:flutter_test/flutter_test.dart';
// import 'package:get/get.dart';

import 'package:vtap/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build app
    await tester.pumpWidget(
      const MyApp(),
    );

    // Verify login screen appears
    expect(find.text('VTAP'), findsOneWidget);

    expect(find.text('LOGIN'), findsOneWidget);
  });
}
