import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/models/asteroid_belt.dart';
import 'package:solar_system_app/models/body_catalog.dart';

/// Semi-major axis whose orbital period is in `jupiterOrbits:orbits` ratio
/// with Jupiter's — where Jupiter's repeated tugs clear a Kirkwood gap.
double resonanceAxis(int orbits, int jupiterOrbits) {
  final double jupiter = BodyCatalog.jupiter.elements!.semiMajorAxisAu;
  return jupiter * math.pow(jupiterOrbits / orbits, 2.0 / 3.0).toDouble();
}

/// How many asteroids have a semi-major axis within [width] of [centre].
int countNear(AsteroidBelt belt, double centre, double width) {
  int total = 0;
  for (int i = 0; i < belt.count; i++) {
    if ((belt.semiMajorAxis[i] - centre).abs() <= width) {
      total++;
    }
  }
  return total;
}

void main() {
  late AsteroidBelt belt;

  setUpAll(() {
    belt = AsteroidBelt.parse(
      File('assets/data/asteroids.csv').readAsStringSync(),
    );
  });

  group('The population', () {
    test('is large enough to read as a belt', () {
      expect(belt.count, greaterThan(4000));
    });

    test('sits between Mars and Jupiter', () {
      final double mars = BodyCatalog.mars.elements!.semiMajorAxisAu;
      final double jupiter = BodyCatalog.jupiter.elements!.semiMajorAxisAu;

      for (int i = 0; i < belt.count; i++) {
        expect(belt.semiMajorAxis[i], greaterThan(mars));
        expect(belt.semiMajorAxis[i], lessThan(jupiter));
      }
    });

    test('matches the measured spread of the real belt', () {
      double eccentricity = 0;
      double maximum = 0;
      for (int i = 0; i < belt.count; i++) {
        eccentricity += belt.eccentricity[i];
        maximum = math.max(maximum, belt.eccentricity[i]);
      }
      // The real main belt averages about 0.14, and few exceed 0.35.
      expect(eccentricity / belt.count, inInclusiveRange(0.10, 0.18));
      expect(maximum, lessThan(0.40));
    });
  });

  group('Kirkwood gaps', () {
    test('fall where Jupiter clears them', () {
      // Each gap is checked against the belt on either side of it, so this
      // measures a real depletion rather than a dip in overall density.
      const List<List<int>> resonances = <List<int>>[
        <int>[3, 1],
        <int>[5, 2],
        <int>[2, 1],
      ];

      for (final List<int> ratio in resonances) {
        final double gap = resonanceAxis(ratio[0], ratio[1]);
        final int inside = countNear(belt, gap, 0.015);
        final int outside = countNear(belt, gap - 0.09, 0.015) +
            countNear(belt, gap + 0.09, 0.015);

        expect(inside * 4, lessThan(outside),
            reason: '${ratio[0]}:${ratio[1]} gap at '
                '${gap.toStringAsFixed(3)} AU holds $inside against '
                '$outside on either side');
      }
    });

    test('the 3:1 gap is where it is observed, near 2.50 AU', () {
      expect(resonanceAxis(3, 1), closeTo(2.50, 0.02));
      expect(resonanceAxis(5, 2), closeTo(2.82, 0.02));
      expect(resonanceAxis(2, 1), closeTo(3.28, 0.02));
    });
  });

  group('The belt has thickness', () {
    test('asteroids sit above and below the ecliptic', () {
      belt.updatePositions(0.0);

      double highest = 0;
      double total = 0;
      for (int i = 0; i < belt.count; i++) {
        final double z = belt.positions[i * 3 + 2].abs();
        highest = math.max(highest, z);
        total += z;
      }

      // Inclinations reach past 30 degrees, so the belt is a torus rather
      // than a ring: some asteroids stand an AU out of the plane.
      expect(highest, greaterThan(0.8));
      expect(total / belt.count, inInclusiveRange(0.15, 0.6));
    });
  });

  group('They orbit properly', () {
    test('each stays between its own perihelion and aphelion', () {
      belt.updatePositions(4000.0);

      for (int i = 0; i < belt.count; i++) {
        final double a = belt.semiMajorAxis[i];
        final double e = belt.eccentricity[i];
        final double x = belt.positions[i * 3];
        final double y = belt.positions[i * 3 + 1];
        final double z = belt.positions[i * 3 + 2];
        final double r = math.sqrt(x * x + y * y + z * z);

        expect(r, greaterThanOrEqualTo(a * (1 - e) - 1e-6));
        expect(r, lessThanOrEqualTo(a * (1 + e) + 1e-6));
      }
    });

    test('an asteroid returns to its starting point after one orbit', () {
      belt.updatePositions(0.0);
      final List<double> start = <double>[
        belt.positions[0],
        belt.positions[1],
        belt.positions[2],
      ];

      // Kepler's third law gives the period from the semi-major axis.
      final double period =
          365.256363004 * math.pow(belt.semiMajorAxis[0], 1.5).toDouble();
      belt.updatePositions(period, tolerance: 0.0);

      for (int axis = 0; axis < 3; axis++) {
        expect(belt.positions[axis], closeTo(start[axis], 1e-6));
      }
      // The inner edge of the belt goes round in just under three years, the
      // outer edge in just under six.
      expect(period / 365.25, inInclusiveRange(2.9, 6.0));
    });

    test('the whole belt updates fast enough to animate', () {
      final Stopwatch watch = Stopwatch()..start();
      for (int frame = 0; frame < 20; frame++) {
        belt.updatePositions(frame * 50.0, tolerance: 0.0);
      }
      watch.stop();

      final double perUpdate = watch.elapsedMicroseconds / 20 / 1000;
      // ignore: avoid_print
      print('belt update: ${perUpdate.toStringAsFixed(2)} ms '
          'for ${belt.count} asteroids');
      expect(perUpdate, lessThan(16.0));
    });

    test('positions are reused until the clock has moved', () {
      belt.updatePositions(1000.0, tolerance: 0.0);
      final double before = belt.positions[0];

      belt.updatePositions(1000.05);
      expect(belt.positions[0], before, reason: 'should not recompute');

      belt.updatePositions(1400.0);
      expect(belt.positions[0], isNot(before));
    });
  });
}
