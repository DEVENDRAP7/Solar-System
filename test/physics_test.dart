import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/physics/kepler.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:vector_math/vector_math_64.dart';

/// Ecliptic longitude in degrees, 0 to 360.
double longitudeOf(Vector3 position) {
  final double degrees = math.atan2(position.y, position.x) * 180.0 / math.pi;
  return degrees < 0 ? degrees + 360.0 : degrees;
}

void main() {
  group('Kepler equation', () {
    test('a circular orbit has eccentric anomaly equal to mean anomaly', () {
      for (double m = -3.0; m < 3.0; m += 0.25) {
        expect(Kepler.eccentricAnomaly(m, 0.0), closeTo(m, 1e-12));
      }
    });

    test('the solution satisfies M = E - e sin E', () {
      for (final double e in <double>[0.0, 0.02, 0.2, 0.5, 0.9, 0.97]) {
        for (double m = -3.0; m < 3.0; m += 0.37) {
          final double anomaly = Kepler.eccentricAnomaly(m, e);
          expect(anomaly - e * math.sin(anomaly), closeTo(m, 1e-8),
              reason: 'e=$e M=$m');
        }
      }
    });
  });

  group('Julian dates', () {
    test('J2000 is 2451545.0', () {
      final DateTime j2000 = DateTime.utc(2000, 1, 1, 12);
      expect(Kepler.julianDate(j2000), closeTo(2451545.0, 1e-6));
      expect(Kepler.centuriesSinceJ2000(j2000), closeTo(0.0, 1e-9));
    });

    test('one century on is 2100', () {
      final DateTime later = DateTime.utc(2000, 1, 1, 12)
          .add(const Duration(days: 36525));
      expect(Kepler.centuriesSinceJ2000(later), closeTo(1.0, 1e-9));
    });
  });

  group('Planet positions', () {
    test('Earth sits at its published mean longitude at J2000', () {
      // Earth's mean longitude at J2000 is 100.46°. The true longitude differs
      // by the equation of centre, under 2° for an orbit this circular.
      final Vector3 earth =
          Kepler.position(BodyCatalog.earth.elements!, 0.0);
      expect(longitudeOf(earth), closeTo(100.46, 2.0));
    });

    test('Earth stays between perihelion and aphelion all year', () {
      for (int day = 0; day < 366; day++) {
        final DateTime date = DateTime.utc(2026, 1, 1).add(Duration(days: day));
        final Vector3 position = Kepler.position(
          BodyCatalog.earth.elements!,
          Kepler.centuriesSinceJ2000(date),
        );
        expect(position.length, inInclusiveRange(0.9825, 1.0175),
            reason: 'day $day');
      }
    });

    test('Earth reaches perihelion in early January', () {
      double closest = double.infinity;
      int closestDay = -1;
      for (int day = 0; day < 366; day++) {
        final DateTime date = DateTime.utc(2026, 1, 1).add(Duration(days: day));
        final double r = Kepler.position(
          BodyCatalog.earth.elements!,
          Kepler.centuriesSinceJ2000(date),
        ).length;
        if (r < closest) {
          closest = r;
          closestDay = day;
        }
      }
      // Perihelion falls on 2-5 January.
      expect(closestDay, lessThan(10));
      expect(closest, closeTo(0.9833, 0.002));
    });

    test('planets keep their order out from the Sun', () {
      final SolarSystemSimulation sim =
          SolarSystemSimulation(start: DateTime.utc(2026, 9, 8));
      double previous = 0.0;
      for (final CelestialBody planet in BodyCatalog.planets) {
        final double r = sim.heliocentricPosition(planet).length;
        expect(r, greaterThan(previous), reason: planet.label);
        previous = r;
      }
    });

    test('orbital periods match the published values', () {
      // Measured by advancing until the heliocentric longitude comes back
      // around, which exercises the whole element-to-position path.
      final Map<CelestialBody, double> expected = <CelestialBody, double>{
        BodyCatalog.mercury: 87.969,
        BodyCatalog.venus: 224.701,
        BodyCatalog.earth: 365.256,
        BodyCatalog.mars: 686.980,
        BodyCatalog.jupiter: 4332.589,
        BodyCatalog.saturn: 10759.22,
        BodyCatalog.uranus: 30685.4,
        BodyCatalog.neptune: 60189.0,
      };

      expected.forEach((CelestialBody body, double periodDays) {
        final double start = longitudeOf(Kepler.position(body.elements!, 0.0));
        final double after = longitudeOf(Kepler.position(
          body.elements!,
          periodDays / Kepler.daysPerCentury,
        ));
        double drift = (after - start).abs();
        if (drift > 180.0) {
          drift = 360.0 - drift;
        }
        // A full period should return the body to within a fraction of a
        // degree of where it started.
        expect(drift, lessThan(1.0), reason: '${body.label} drift $drift°');
      });
    });

    test("Kepler's third law holds across the planets", () {
      for (final CelestialBody planet in BodyCatalog.planets) {
        final double a = planet.elements!.semiMajorAxisAu;
        final double years = planet.orbitalPeriodDays! / 365.256363004;
        expect(years * years / (a * a * a), closeTo(1.0, 0.001),
            reason: planet.label);
      }
    });

    test('the Moon stays within its real distance range of Earth', () {
      final SolarSystemSimulation sim =
          SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
      const double kmPerAu = 1.495978707e8;
      double minimum = double.infinity;
      double maximum = 0.0;

      for (int day = 0; day < 60; day++) {
        sim.time = DateTime.utc(2026, 1, 1).add(Duration(days: day));
        final double km = sim.relativePosition(BodyCatalog.moon).length * kmPerAu;
        minimum = math.min(minimum, km);
        maximum = math.max(maximum, km);
      }
      // Real perigee and apogee are about 363,300 and 405,500 km.
      expect(minimum, inInclusiveRange(355000, 375000));
      expect(maximum, inInclusiveRange(395000, 415000));
    });

    test('the Moon completes a lunar month', () {
      final SolarSystemSimulation sim =
          SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
      final Vector3 start = sim.relativePosition(BodyCatalog.moon);
      sim.time = DateTime.utc(2026, 1, 1)
          .add(const Duration(days: 27, hours: 7, minutes: 43));
      final Vector3 after = sim.relativePosition(BodyCatalog.moon);

      final double angle =
          start.angleTo(after) * 180.0 / math.pi;
      expect(angle, lessThan(2.0), reason: 'sidereal month drift $angle°');
    });
  });

  group('Simulation clock', () {
    test('time scale advances the clock proportionally', () {
      final SolarSystemSimulation sim =
          SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
      sim.daysPerSecond = 10.0;
      sim.advance(2.5);
      expect(sim.julianDate - Kepler.julianDate(DateTime.utc(2026, 1, 1)),
          closeTo(25.0, 1e-9));
    });

    test('pausing stops the clock', () {
      final SolarSystemSimulation sim =
          SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
      sim.paused = true;
      sim.advance(100.0);
      expect(sim.daysSinceJ2000,
          closeTo(Kepler.julianDate(DateTime.utc(2026, 1, 1)) - 2451545.0, 1e-9));
    });

    test('retrograde bodies spin the other way', () {
      // spinRadians reports an angle in 0..2*pi, so direction shows up in how
      // the angle moves over time rather than in its sign.
      double step(CelestialBody body) {
        final SolarSystemSimulation sim =
            SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
        final double before = sim.spinRadians(body);
        sim.daysPerSecond = 1.0;
        sim.advance(0.01);
        final double after = sim.spinRadians(body);
        double delta = after - before;
        if (delta > math.pi) {
          delta -= 2 * math.pi;
        } else if (delta < -math.pi) {
          delta += 2 * math.pi;
        }
        return delta;
      }

      expect(step(BodyCatalog.earth), greaterThan(0.0));
      expect(step(BodyCatalog.mars), greaterThan(0.0));
      // Venus and Uranus turn backwards.
      expect(step(BodyCatalog.venus), lessThan(0.0));
      expect(step(BodyCatalog.uranus), lessThan(0.0));
    });
  });

  group('View scale', () {
    test('explore mode preserves ordering of distances', () {
      const ViewScale scale = ViewScale();
      double previous = 0.0;
      for (final CelestialBody planet in BodyCatalog.planets) {
        final double units =
            scale.distance(planet.elements!.semiMajorAxisAu);
        expect(units, greaterThan(previous), reason: planet.label);
        previous = units;
      }
    });

    test('explore mode preserves ordering of radii', () {
      const ViewScale scale = ViewScale();
      expect(scale.bodyRadius(BodyCatalog.jupiter.radiusKm),
          greaterThan(scale.bodyRadius(BodyCatalog.earth.radiusKm)));
      expect(scale.bodyRadius(BodyCatalog.earth.radiusKm),
          greaterThan(scale.bodyRadius(BodyCatalog.moon.radiusKm)));
      expect(scale.bodyRadius(BodyCatalog.sun.radiusKm),
          greaterThan(scale.bodyRadius(BodyCatalog.jupiter.radiusKm)));
    });

    test('the Sun does not swallow the innermost orbit', () {
      const ViewScale scale = ViewScale();
      final double sunRadius = scale.bodyRadius(BodyCatalog.sun.radiusKm);
      final double mercuryOrbit =
          scale.distance(BodyCatalog.mercury.elements!.semiMajorAxisAu);
      expect(sunRadius, lessThan(mercuryOrbit * 0.5));
    });

    test('planets stay clear of each other in explore mode', () {
      const ViewScale scale = ViewScale();
      final List<CelestialBody> planets = BodyCatalog.planets;
      for (int i = 1; i < planets.length; i++) {
        final double inner =
            scale.distance(planets[i - 1].elements!.semiMajorAxisAu);
        final double outer =
            scale.distance(planets[i].elements!.semiMajorAxisAu);
        final double gap = outer - inner;
        final double radii = scale.bodyRadius(planets[i - 1].radiusKm) +
            scale.bodyRadius(planets[i].radiusKm);
        expect(gap, greaterThan(radii),
            reason: '${planets[i - 1].label} to ${planets[i].label}');
      }
    });

    test('true scale makes planets vanishingly small, as it should', () {
      const ViewScale scale = ViewScale(mode: ScaleMode.trueScale);
      final double earthRadius = scale.bodyRadius(BodyCatalog.earth.radiusKm);
      final double earthOrbit = scale.distance(1.0);
      expect(earthRadius / earthOrbit, lessThan(0.001));
    });

    test('the Moon is drawn outside its planet', () {
      const ViewScale scale = ViewScale();
      final double earthRadius = scale.bodyRadius(BodyCatalog.earth.radiusKm);
      final double moonRadius =
          scale.bodyRadius(BodyCatalog.moon.radiusKm, isMoon: true);
      final double moonDistance = scale.satelliteDistance(
        astronomicalUnits: 0.00257,
        semiMajorAxisAu: 0.00257,
        parentRadiusKm: BodyCatalog.earth.radiusKm,
        parentRadiusUnits: earthRadius,
        moonRadiusUnits: moonRadius,
      );
      expect(moonDistance, greaterThan(earthRadius + moonRadius));
    });
  });

  group('Catalog and generated models agree', () {
    test('every body has a model file, and radii match the manifest', () {
      final File file = File('assets/data/bodies.json');
      expect(file.existsSync(), isTrue,
          reason: 'run tools/blender/build_models.py');

      final Map<String, dynamic> manifest =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final List<dynamic> entries = manifest['bodies'] as List<dynamic>;

      final Map<String, Map<String, dynamic>> byKey =
          <String, Map<String, dynamic>>{
        for (final dynamic entry in entries)
          (entry as Map<String, dynamic>)['key'] as String: entry,
      };

      for (final CelestialBody body in BodyCatalog.all) {
        expect(byKey.containsKey(body.key), isTrue,
            reason: 'no generated model for ${body.key}');
        expect(File(body.modelAsset).existsSync(), isTrue,
            reason: '${body.modelAsset} missing');
        expect((byKey[body.key]!['radiusKm'] as num).toDouble(),
            closeTo(body.radiusKm, 0.001),
            reason: '${body.label} radius drifted from the manifest');
      }

      const CelestialBody saturn = BodyCatalog.saturn;
      expect(File(saturn.ringModelAsset!).existsSync(), isTrue);
    });
  });
}
