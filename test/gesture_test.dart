import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/mesh_library.dart';
import 'package:solar_system_app/widgets/solar_system_view.dart';

void main() {
  late MeshLibrary library;
  late SolarSystemSimulation simulation;
  late ValueNotifier<int> recenter;

  setUp(() {
    library = MeshLibrary();
    simulation = SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
    recenter = ValueNotifier<int>(0);
  });

  tearDown(() {
    library.dispose();
    recenter.dispose();
  });

  Widget harness({
    required void Function(bool) onInteracting,
    void Function(String?)? onTap,
    DragMode mode = DragMode.orbit,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SolarSystemView(
          simulation: simulation,
          library: library,
          scale: const ViewScale(),
          showOrbits: false,
          showMoons: false,
          showBelt: false,
          belt: null,
          focusKey: null,
          dragMode: mode,
          onTapBody: onTap ?? (String? _) {},
          onFrame: (double _) {},
          onInteracting: onInteracting,
          recenterRequests: recenter,
        ),
      ),
    );
  }

  testWidgets('time is held while a finger is down, and runs again after',
      (WidgetTester tester) async {
    final List<bool> states = <bool>[];
    await tester.pumpWidget(harness(onInteracting: states.add));

    final TestGesture gesture =
        await tester.startGesture(const Offset(200, 300));
    await tester.pump();
    await gesture.moveBy(const Offset(60, 20));
    await tester.pump();

    expect(states.first, isTrue, reason: 'the clock should hold on touch');

    await gesture.up();
    await tester.pump();

    expect(states.last, isFalse, reason: 'and run again on release');
  });

  testWidgets('a drag does not report a body tap', (WidgetTester tester) async {
    final List<String?> taps = <String?>[];
    await tester.pumpWidget(
      harness(onInteracting: (bool _) {}, onTap: taps.add),
    );

    // A drag past the slop is a drag, not a tap on empty space.
    await tester.drag(find.byType(SolarSystemView), const Offset(120, 40));
    await tester.pump();

    expect(taps, isEmpty);
  });

  testWidgets('a tap on empty space clears the selection',
      (WidgetTester tester) async {
    final List<String?> taps = <String?>[];
    await tester.pumpWidget(
      harness(onInteracting: (bool _) {}, onTap: taps.add),
    );

    await tester.tapAt(const Offset(60, 120));
    await tester.pump();

    expect(taps, <String?>[null]);
  });

  testWidgets('both drag modes are accepted', (WidgetTester tester) async {
    for (final DragMode mode in DragMode.values) {
      final List<bool> states = <bool>[];
      await tester.pumpWidget(harness(onInteracting: states.add, mode: mode));

      await tester.drag(find.byType(SolarSystemView), const Offset(80, 30));
      await tester.pump();

      expect(states, isNotEmpty, reason: '$mode should handle a drag');
    }
  });
}
