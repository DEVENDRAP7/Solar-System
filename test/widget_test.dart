import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/main.dart';

void main() {
  testWidgets('app renders the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SolarSystemApp());

    expect(find.text('Solar System'), findsOneWidget);
    expect(
      find.text('Interactive 3D Solar System for mobile exploration.'),
      findsOneWidget,
    );
  });
}
