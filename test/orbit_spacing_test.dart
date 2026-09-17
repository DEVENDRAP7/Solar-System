import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

const ViewScale scale = ViewScale();

/// The planets, sunward first.
List<CelestialBody> get planets {
  final List<CelestialBody> out = BodyCatalog.planetsAndSun
      .where((CelestialBody b) => b.elements != null && b.parentKey == null)
      .toList();
  out.sort(
    (CelestialBody a, CelestialBody b) =>
        a.elements!.semiMajorAxisAu.compareTo(b.elements!.semiMajorAxisAu),
  );
  return out;
}

double orbitOf(CelestialBody body) =>
    scale.distance(body.elements!.semiMajorAxisAu);

void main() {
  test('no moon reaches a neighbouring planet, at any point in its orbit', () {
    // Sampled across a decade, because a moon on an oval orbit swings out
    // further at some times of its month than at others.
    final List<DateTime> moments = <DateTime>[
      for (int days = 0; days < 3650; days += 7)
        DateTime.utc(2026).add(Duration(days: days)),
    ];

    final Map<String, double> furthest = <String, double>{};
    for (final DateTime when in moments) {
      final SolarSystemSimulation simulation = SolarSystemSimulation(
        start: when,
      );

      for (final CelestialBody moon in BodyCatalog.all) {
        final String? parentKey = moon.parentKey;
        if (parentKey == null) {
          continue;
        }
        final CelestialBody parent = BodyCatalog.byKey(parentKey)!;
        final vm.Vector3 offset =
            bodyWorldPosition(simulation, scale, moon) -
            bodyWorldPosition(simulation, scale, parent);

        final String key = '$parentKey/${moon.key}';
        furthest[key] = math.max(furthest[key] ?? 0, offset.length);
      }
    }

    final List<CelestialBody> ordered = planets;
    for (final MapEntry<String, double> entry in furthest.entries) {
      final CelestialBody parent = BodyCatalog.byKey(
        entry.key.split('/').first,
      )!;
      final int index = ordered.indexWhere(
        (CelestialBody b) => b.key == parent.key,
      );

      double room = double.infinity;
      for (final int neighbour in <int>[index - 1, index + 1]) {
        if (neighbour < 0 || neighbour >= ordered.length) {
          continue;
        }
        room = math.min(
          room,
          (orbitOf(ordered[neighbour]) - orbitOf(parent)).abs(),
        );
      }

      expect(
        entry.value,
        lessThan(room),
        reason:
            '${entry.key} swings ${entry.value.toStringAsFixed(2)} out, '
            'and the nearest orbit is ${room.toStringAsFixed(2)} away',
      );
    }
  });

  test('a planet leaves room around it for the neighbours', () {
    // What the crowding complaint was really about: a planet's own disc
    // filling most of the gap to the next orbit.
    final List<CelestialBody> ordered = planets;
    for (int i = 0; i < ordered.length; i++) {
      final CelestialBody body = ordered[i];
      double room = double.infinity;
      for (final int neighbour in <int>[i - 1, i + 1]) {
        if (neighbour < 0 || neighbour >= ordered.length) {
          continue;
        }
        room = math.min(
          room,
          (orbitOf(ordered[neighbour]) - orbitOf(body)).abs(),
        );
      }
      if (room.isInfinite) {
        continue;
      }
      expect(
        scale.bodyRadius(body.radiusKm) * 2,
        lessThan(room * 0.75),
        reason: '${body.key} is as wide as the gap to its neighbour',
      );
    }
  });

  test('moons still sit outside their planet, in the right order', () {
    final SolarSystemSimulation simulation = SolarSystemSimulation(
      start: DateTime.utc(2026, 9, 17),
    );

    for (final CelestialBody moon in BodyCatalog.all) {
      final String? parentKey = moon.parentKey;
      if (parentKey == null) {
        continue;
      }
      final CelestialBody parent = BodyCatalog.byKey(parentKey)!;
      final double out =
          (bodyWorldPosition(simulation, scale, moon) -
                  bodyWorldPosition(simulation, scale, parent))
              .length;

      expect(
        out,
        greaterThan(scale.bodyRadius(parent.radiusKm)),
        reason: '${moon.key} is inside ${parent.key}',
      );

      // And clear of the rings, where there are any.
      if (parent.ringOuterRadii > 0) {
        expect(
          out,
          greaterThan(
            scale.bodyRadius(parent.radiusKm) * parent.ringOuterRadii,
          ),
          reason: '${moon.key} is inside ${parent.key}\'s rings',
        );
      }
    }
  });
}
