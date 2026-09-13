import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/body_inspector.dart';
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
    String? focusKey,
    BodyInspector? inspector,
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
          focusKey: focusKey,
          dragMode: mode,
          inspector: inspector,
          onTapBody: onTap ?? (String? _) {},
          onFrame: (double _) {},
          onInteracting: onInteracting,
          recenterRequests: recenter,
        ),
      ),
    );
  }

  testWidgets('time is held while a finger is down, and runs again after', (
    WidgetTester tester,
  ) async {
    final List<bool> states = <bool>[];
    await tester.pumpWidget(harness(onInteracting: states.add));

    final TestGesture gesture = await tester.startGesture(
      const Offset(200, 300),
    );
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

  testWidgets('a tap on empty space clears the selection', (
    WidgetTester tester,
  ) async {
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

  testWidgets('a drag turns the selected body, not the camera', (
    WidgetTester tester,
  ) async {
    final BodyInspector inspector = BodyInspector();
    await tester.pumpWidget(
      harness(
        onInteracting: (bool _) {},
        focusKey: 'mars',
        inspector: inspector,
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(SolarSystemView), const Offset(140, 60));
    await tester.pump();

    // The turn landed on Mars. The camera was not asked to move, so the
    // planets, orbits and belt behind it are exactly where they were.
    expect(inspector.key, 'mars');
    expect(inspector.spinFor('mars').abs(), greaterThan(0.2));
    expect(inspector.pitch.abs(), greaterThan(0.1));
  });

  testWidgets('with nothing selected a drag leaves every body alone', (
    WidgetTester tester,
  ) async {
    final BodyInspector inspector = BodyInspector();
    await tester.pumpWidget(
      harness(onInteracting: (bool _) {}, inspector: inspector),
    );

    await tester.drag(find.byType(SolarSystemView), const Offset(140, 60));
    await tester.pump();

    // Nothing is being inspected, so the drag swung the camera instead.
    expect(inspector.isActive, isFalse);
    expect(inspector.yaw, 0.0);
  });

  testWidgets('sliding away from a body hands the drag back to the camera', (
    WidgetTester tester,
  ) async {
    final BodyInspector inspector = BodyInspector();
    await tester.pumpWidget(
      harness(
        onInteracting: (bool _) {},
        mode: DragMode.move,
        focusKey: 'mars',
        inspector: inspector,
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(SolarSystemView), const Offset(120, 40));
    await tester.pump();

    expect(inspector.isActive, isFalse);
  });

  testWidgets('a flick keeps the view moving, then settles', (
    WidgetTester tester,
  ) async {
    final BodyInspector inspector = BodyInspector();
    await tester.pumpWidget(
      harness(
        onInteracting: (bool _) {},
        focusKey: 'mars',
        inspector: inspector,
      ),
    );
    await tester.pump();

    // A quick flick: enough distance in enough of a hurry to count as a throw.
    await tester.fling(find.byType(SolarSystemView), const Offset(220, 0), 900);
    await tester.pump();

    final double onRelease = inspector.yaw;
    expect(onRelease.abs(), greaterThan(0.0));

    // It should carry on after the finger has gone...
    await tester.pump(const Duration(milliseconds: 120));
    final double coasting = inspector.yaw;
    expect(
      coasting.abs(),
      greaterThan(onRelease.abs()),
      reason: 'the throw should carry the turn past where the finger left it',
    );

    // ...and then stop, rather than spinning for ever.
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final double settled = inspector.yaw;
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      inspector.yaw,
      closeTo(settled, 1e-9),
      reason: 'the glide should come to rest',
    );
  });

  testWidgets('putting a finger down stops the glide dead', (
    WidgetTester tester,
  ) async {
    final BodyInspector inspector = BodyInspector();
    await tester.pumpWidget(
      harness(
        onInteracting: (bool _) {},
        focusKey: 'mars',
        inspector: inspector,
      ),
    );
    await tester.pump();

    await tester.fling(find.byType(SolarSystemView), const Offset(220, 0), 900);
    await tester.pump(const Duration(milliseconds: 60));

    // Catch it, the way you would catch a spinning globe.
    final TestGesture catcher = await tester.startGesture(
      const Offset(200, 300),
    );
    await tester.pump();
    final double caught = inspector.yaw;

    await tester.pump(const Duration(milliseconds: 300));
    expect(inspector.yaw, closeTo(caught, 1e-9));

    await catcher.up();
    await tester.pump();
  });
}
