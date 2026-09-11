import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/physics/simulation.dart';

const double kmPerAu = 1.495978707e8;

List<CelestialBody> moonsOf(String parent) => BodyCatalog.moons
    .where((CelestialBody body) => body.parentKey == parent)
    .toList();

/// Where a moon is drawn, in scene units from its planet's centre.
double drawnDistance(CelestialBody moon, {double phase = 1.0}) {
  const ViewScale scale = ViewScale();
  final CelestialBody parent = BodyCatalog.byKey(moon.parentKey!)!;
  final double a = moon.elements!.semiMajorAxisAu;

  return scale.satelliteDistance(
    astronomicalUnits: a * phase,
    semiMajorAxisAu: a,
    parentRadiusKm: parent.radiusKm,
    parentRadiusUnits: scale.bodyRadius(parent.radiusKm),
    moonRadiusUnits: scale.bodyRadius(moon.radiusKm, isMoon: true),
  );
}

void main() {
  group('The moons are there', () {
    test('every planet with major moons has them', () {
      expect(moonsOf('mars').length, 2);
      expect(moonsOf('jupiter').length, 4, reason: 'the Galilean moons');
      expect(moonsOf('saturn').length, 7);
      expect(moonsOf('uranus').length, 5);
      expect(moonsOf('neptune').length, 2);
      expect(BodyCatalog.moons.length, 20);
    });

    test('the Galilean moons are named and in order', () {
      expect(
        moonsOf('jupiter').map((CelestialBody m) => m.label).toList(),
        <String>['Io', 'Europa', 'Ganymede', 'Callisto'],
      );
    });

    test('all of them are moons of a real planet', () {
      for (final CelestialBody moon in BodyCatalog.moons) {
        expect(moon.type, BodyType.moon, reason: moon.label);
        expect(BodyCatalog.byKey(moon.parentKey!), isNotNull,
            reason: '${moon.label} has no parent');
        expect(moon.elements, isNotNull, reason: moon.label);
      }
    });
  });

  group('Their orbits are the real ones', () {
    test('published periods and radii come back out', () {
      // A spot check against the values these moons are catalogued with.
      final Map<String, List<double>> expected = <String, List<double>>{
        // key: [semi-major axis km, period days, radius km]
        'io': <double>[421700, 1.769138, 1821.6],
        'europa': <double>[671034, 3.551181, 1560.8],
        'ganymede': <double>[1070412, 7.154553, 2634.1],
        'callisto': <double>[1882709, 16.689018, 2410.3],
        'titan': <double>[1221870, 15.945421, 2574.7],
        'triton': <double>[354759, 5.876854, 1353.4],
        'phobos': <double>[9376, 0.31891, 11.27],
      };

      expected.forEach((String key, List<double> values) {
        final CelestialBody moon = BodyCatalog.byKey(key)!;
        expect(moon.elements!.semiMajorAxisAu * kmPerAu,
            closeTo(values[0], 1.0), reason: '$key orbital radius');
        expect(moon.orbitalPeriodDays, closeTo(values[1], 1e-5),
            reason: '$key period');
        expect(moon.radiusKm, closeTo(values[2], 0.05), reason: '$key radius');
      });
    });

    test('each is tidally locked, turning once per orbit', () {
      for (final CelestialBody moon in BodyCatalog.moons) {
        expect(moon.rotationHours, closeTo(moon.orbitalPeriodDays! * 24, 1e-6),
            reason: moon.label);
      }
    });

    test('Ganymede is larger than Mercury', () {
      expect(BodyCatalog.byKey('ganymede')!.radiusKm,
          greaterThan(BodyCatalog.mercury.radiusKm));
    });

    test("Uranus's moons orbit nearly upright with the tipped planet", () {
      for (final CelestialBody moon in moonsOf('uranus')) {
        // The planet is tilted 98 degrees and its moons went with it, so their
        // orbits stand almost perpendicular to the ecliptic.
        expect(moon.elements!.inclinationDeg, inInclusiveRange(93.0, 103.0),
            reason: moon.label);
      }
    });

    test('Triton goes round backwards', () {
      // An inclination past 90 degrees is a retrograde orbit, the sign that
      // Neptune captured Triton rather than forming with it.
      expect(BodyCatalog.byKey('triton')!.elements!.inclinationDeg,
          greaterThan(90.0));
    });

    test('they move at the right rate', () {
      final SolarSystemSimulation sim =
          SolarSystemSimulation(start: DateTime.utc(2026, 1, 1));
      final CelestialBody io = BodyCatalog.byKey('io')!;

      final start = sim.relativePosition(io);
      sim.time = DateTime.utc(2026, 1, 1)
          .add(const Duration(hours: 42, minutes: 27, seconds: 33));
      final after = sim.relativePosition(io);

      // Io goes round Jupiter in 1.769 days, so after one period it is back.
      expect(start.angleTo(after) * 180 / math.pi, lessThan(2.0));
    });
  });

  group('Where they are drawn', () {
    test('they keep their real order out from the planet', () {
      for (final String planet in <String>[
        'mars', 'jupiter', 'saturn', 'uranus', 'neptune',
      ]) {
        final List<CelestialBody> moons = moonsOf(planet);
        double previous = 0;
        for (final CelestialBody moon in moons) {
          final double distance = drawnDistance(moon);
          expect(distance, greaterThan(previous),
              reason: '${moon.label} should be drawn beyond the one inside it');
          previous = distance;
        }
      }
    });

    test('none is drawn inside its planet', () {
      const ViewScale scale = ViewScale();
      for (final CelestialBody moon in BodyCatalog.moons) {
        final CelestialBody parent = BodyCatalog.byKey(moon.parentKey!)!;
        final double surface = scale.bodyRadius(parent.radiusKm);
        expect(drawnDistance(moon, phase: 0.6), greaterThan(surface),
            reason: '${moon.label} would be inside ${parent.label}');
      }
    });

    test("Mimas stays outside Saturn's rings, where it really is", () {
      const ViewScale scale = ViewScale();
      final double ringOuter = BodyCatalog.saturn.ringOuterRadii *
          scale.bodyRadius(BodyCatalog.saturn.radiusKm);
      expect(drawnDistance(BodyCatalog.byKey('mimas')!, phase: 0.8),
          greaterThan(ringOuter));
    });

    test('the moons are drawn smaller than their planets', () {
      const ViewScale scale = ViewScale();
      for (final CelestialBody moon in BodyCatalog.moons) {
        final CelestialBody parent = BodyCatalog.byKey(moon.parentKey!)!;
        expect(scale.bodyRadius(moon.radiusKm, isMoon: true),
            lessThan(scale.bodyRadius(parent.radiusKm)),
            reason: '${moon.label} vs ${parent.label}');
      }
    });
  });
}
