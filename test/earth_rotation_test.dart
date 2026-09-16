import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/surface_feature.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:vector_math/vector_math_64.dart';

/// Where the Sun actually stands over the Earth the app draws, read back out
/// of the scene the same way the painter builds it.
///
/// This is the whole point of the test: not that the maths agrees with itself,
/// but that the globe on screen has the right face turned to the light.
({double latitude, double longitude}) subsolarPointFromScene(DateTime when) {
  final SolarSystemSimulation simulation = SolarSystemSimulation(start: when);
  final Vector3 world = bodyWorldPosition(
    simulation,
    const ViewScale(),
    BodyCatalog.earth,
  );
  final Vector3 toSun = (-world).normalized();

  // Exactly the model matrix _paintBodies uses, minus the scale, which does
  // not turn anything.
  final Matrix4 model = Matrix4.identity()
    ..rotateX(-BodyCatalog.earth.axialTiltDeg * math.pi / 180.0)
    ..rotateY(simulation.spinRadians(BodyCatalog.earth));

  // Undo it, to ask which point on the map is the one facing the Sun.
  final Matrix4 inverse = Matrix4.inverted(model);
  final Vector3 onMap = inverse.rotated3(toSun)..normalize();

  return (
    latitude: math.asin(onMap.y.clamp(-1.0, 1.0)) * 180.0 / math.pi,
    longitude: SurfaceFeature.longitudeOf(onMap),
  );
}

double degreesApart(double a, double b) {
  final double difference = (a - b).abs() % 360.0;
  return difference > 180.0 ? 360.0 - difference : difference;
}

void main() {
  group('the Sun stands over the right place', () {
    test('noon UTC puts it near the prime meridian', () {
      final point = subsolarPointFromScene(DateTime.utc(2026, 3, 21, 12));
      expect(
        degreesApart(point.longitude, 0.0),
        lessThan(5.0),
        reason: 'got ${point.longitude}',
      );
    });

    test('midnight UTC puts it near the date line', () {
      final point = subsolarPointFromScene(DateTime.utc(2026, 3, 21, 0));
      expect(
        degreesApart(point.longitude, 180.0),
        lessThan(5.0),
        reason: 'got ${point.longitude}',
      );
    });

    test('India has the Sun overhead in the morning, UTC', () {
      // Solar noon over 78 degrees east — the middle of India — is a little
      // before seven in the morning in London.
      final point = subsolarPointFromScene(DateTime.utc(2026, 9, 16, 6, 48));
      expect(
        degreesApart(point.longitude, 78.0),
        lessThan(6.0),
        reason: 'got ${point.longitude}',
      );
    });

    test('it turns fifteen degrees an hour, westward', () {
      final DateTime start = DateTime.utc(2026, 6, 1, 0);
      final double first = subsolarPointFromScene(start).longitude;
      final double later = subsolarPointFromScene(
        start.add(const Duration(hours: 6)),
      ).longitude;

      // Six hours on, the Sun stands ninety degrees further west.
      expect(
        degreesApart(first - 90.0, later),
        lessThan(2.0),
        reason: '$first then $later',
      );
    });

    test('the seasons come out right', () {
      // At the solstices the Sun stands over a tropic, not the equator: this
      // is the axial tilt showing up where it should.
      final double june = subsolarPointFromScene(
        DateTime.utc(2026, 6, 21, 12),
      ).latitude;
      final double december = subsolarPointFromScene(
        DateTime.utc(2026, 12, 21, 12),
      ).latitude;

      expect(june, closeTo(23.44, 2.0), reason: 'June solstice');
      expect(december, closeTo(-23.44, 2.0), reason: 'December solstice');
    });

    test('and the equinoxes put it on the equator', () {
      for (final DateTime when in <DateTime>[
        DateTime.utc(2026, 3, 20, 12),
        DateTime.utc(2026, 9, 22, 12),
      ]) {
        expect(
          subsolarPointFromScene(when).latitude.abs(),
          lessThan(2.0),
          reason: '$when',
        );
      }
    });
  });
}
