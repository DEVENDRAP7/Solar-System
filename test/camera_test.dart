import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/providers/solar_system_provider.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('Panning', () {
    test('dragging moves the scene with the finger', () {
      final OrbitCamera camera = OrbitCamera(distance: 20, yaw: 0, pitch: 0);
      final Vector3 before = camera.target.clone();

      // Camera at yaw 0 looks along -z, so screen right is world +x. Dragging
      // right must move the target left for the scene to follow the finger.
      camera.pan(50, 0, 1000);
      expect(camera.target.x, lessThan(before.x));
      expect(camera.target.y, closeTo(before.y, 1e-9));
    });

    test('dragging down moves the target up', () {
      final OrbitCamera camera = OrbitCamera(distance: 20, yaw: 0, pitch: 0);
      camera.pan(0, 40, 1000);
      expect(camera.target.y, greaterThan(0));
    });

    test('pan distance scales with zoom', () {
      final OrbitCamera near = OrbitCamera(distance: 5, yaw: 0, pitch: 0);
      final OrbitCamera far = OrbitCamera(distance: 50, yaw: 0, pitch: 0);

      near.pan(100, 0, 1000);
      far.pan(100, 0, 1000);

      // The same drag covers ten times the distance when ten times as far out.
      expect(far.target.length / near.target.length, closeTo(10.0, 0.001));
    });

    test('panning carries the camera with the target', () {
      final OrbitCamera camera = OrbitCamera(
        distance: 20,
        yaw: 0.4,
        pitch: 0.3,
      );
      final Vector3 eyeBefore = camera.eye;
      camera.pan(60, 25, 1000);

      final Vector3 shift = camera.eye - eyeBefore;
      expect(shift.length, greaterThan(0.1));
      // Distance to the target is unchanged: panning slides, it does not zoom.
      expect((camera.eye - camera.target).length, closeTo(20.0, 1e-9));
    });

    test('pan direction follows the heading', () {
      final OrbitCamera facingOne = OrbitCamera(distance: 20, yaw: 0, pitch: 0);
      final OrbitCamera facingOther = OrbitCamera(
        distance: 20,
        yaw: math.pi,
        pitch: 0,
      );

      facingOne.pan(50, 0, 1000);
      facingOther.pan(50, 0, 1000);

      // Turned around, the same drag moves the opposite way in world terms.
      expect(facingOne.target.x.sign, isNot(facingOther.target.x.sign));
    });
  });

  group('Rotating and zooming', () {
    test('pitch cannot pass the pole', () {
      final OrbitCamera camera = OrbitCamera();
      camera.rotate(0, 100);
      expect(camera.pitch, lessThan(math.pi / 2));
      camera.rotate(0, -200);
      expect(camera.pitch, greaterThan(-math.pi / 2));
    });

    test('zoom stays within its limits', () {
      final OrbitCamera camera = OrbitCamera();
      camera.zoom(1000);
      expect(camera.distance, greaterThanOrEqualTo(camera.minDistance));
      camera.zoom(0.00001);
      expect(camera.distance, lessThanOrEqualTo(camera.maxDistance));
    });

    test('the eye keeps its distance as it swings round', () {
      final OrbitCamera camera = OrbitCamera(distance: 12, yaw: 0, pitch: 0);
      for (int i = 0; i < 12; i++) {
        camera.rotate(0.5, 0.1);
        expect((camera.eye - camera.target).length, closeTo(12.0, 1e-9));
      }
    });

    test('the overview looks at the Sun from a distance', () {
      final OrbitCamera overview = OrbitCamera.overview();
      expect(overview.target, Vector3.zero());
      expect(overview.distance, inInclusiveRange(15.0, 40.0));
    });
  });

  group('Holding time still', () {
    test('a finger on the scene stops the clock', () {
      final SolarSystemProvider provider = SolarSystemProvider(
        start: DateTime.utc(2026, 1, 1),
      );
      addTearDown(provider.dispose);
      provider.setSpeedIndex(3);

      provider.setInteracting(true);
      final double held = provider.simulation.julianDate;
      provider.onFrame(1.0);
      expect(
        provider.simulation.julianDate,
        closeTo(held, 1e-12),
        reason: 'time must not move while the view is being dragged',
      );

      provider.setInteracting(false);
      provider.onFrame(1.0);
      expect(provider.simulation.julianDate, greaterThan(held));
    });

    test('the default speed shows the planets actually moving', () {
      final SolarSystemProvider provider = SolarSystemProvider();
      addTearDown(provider.dispose);

      // Holding the clock while the view is being dragged is what makes a
      // planet sit still to be looked at, so the default no longer has to be
      // slow. It should be quick enough that the inner planets visibly travel:
      // Mercury goes round in 88 days, which should take a couple of minutes.
      final double mercuryOrbitSeconds = 87.969 / provider.speed.daysPerSecond;
      expect(
        mercuryOrbitSeconds,
        lessThan(240),
        reason: 'Mercury should round the Sun within a few minutes',
      );
      expect(
        mercuryOrbitSeconds,
        greaterThan(20),
        reason: 'but not so fast that it is a blur',
      );
    });
  });
}
