import 'package:flutter_test/flutter_test.dart';

import 'package:blood_test_app/main.dart';

void main() {
  testWidgets('Shows an error screen when Firebase fails to initialize', (WidgetTester tester) async {
    await tester.pumpWidget(const BloodTestApp(initializationError: 'no config'));

    expect(find.textContaining('Firebase Init Error'), findsOneWidget);
    expect(find.textContaining('no config'), findsOneWidget);
  });
}
