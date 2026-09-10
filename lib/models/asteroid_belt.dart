import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:convert';

import 'package:flutter/services.dart';

/// The main-belt asteroids, propagated on their own orbits.
///
/// Each asteroid is a Keplerian orbit like any planet, so the belt is not a
/// spinning decoration: it thins where Jupiter's resonances have cleared it,
/// spreads above and below the ecliptic by each body's own inclination, and
/// the inner asteroids lap the outer ones.
///
/// The orientation of an orbit never changes, so the two vectors that rotate
/// it into the ecliptic are worked out once at load. Per frame all that is
/// left is solving Kepler's equation and a pair of scaled additions.
class AsteroidBelt {
  AsteroidBelt._({
    required this.semiMajorAxis,
    required this.eccentricity,
    required this.meanMotion,
    required this.meanAnomalyAtEpoch,
    required this.orbitX,
    required this.orbitY,
  }) : positions = Float64List(semiMajorAxis.length * 3);

  /// Semi-major axes, in astronomical units.
  final Float64List semiMajorAxis;

  final Float64List eccentricity;

  /// Degrees of mean anomaly per day.
  final Float64List meanMotion;

  /// Mean anomaly at J2000, in degrees.
  final Float64List meanAnomalyAtEpoch;

  /// Unit vectors toward perihelion and a quarter turn along the orbit, which
  /// together carry orbital-plane coordinates into the ecliptic frame.
  final Float64List orbitX;
  final Float64List orbitY;

  /// Heliocentric positions in astronomical units, three doubles per asteroid.
  final Float64List positions;

  double _computedAtDay = double.nan;

  int get count => semiMajorAxis.length;

  static const double _degToRad = math.pi / 180.0;

  /// Days in a year, for turning a semi-major axis into a mean motion.
  static const double _daysPerYear = 365.256363004;

  /// Read the belt from its asset.
  static Future<AsteroidBelt> load([
    String asset = 'assets/data/asteroids.csv',
  ]) async {
    final String text = await rootBundle.loadString(asset);
    return parse(text);
  }

  /// Parse the belt from CSV text: one asteroid per line, angles in degrees.
  static AsteroidBelt parse(String text) {
    final List<String> lines = const LineSplitter().convert(text);
    final List<List<double>> rows = <List<double>>[];

    for (final String line in lines) {
      if (line.isEmpty || line.startsWith('a_au')) {
        continue;
      }
      final List<String> parts = line.split(',');
      if (parts.length < 6) {
        continue;
      }
      rows.add(<double>[
        for (int i = 0; i < 6; i++) double.parse(parts[i]),
      ]);
    }

    final int count = rows.length;
    final Float64List axis = Float64List(count);
    final Float64List eccentricity = Float64List(count);
    final Float64List motion = Float64List(count);
    final Float64List anomaly = Float64List(count);
    final Float64List orbitX = Float64List(count * 3);
    final Float64List orbitY = Float64List(count * 3);

    for (int index = 0; index < count; index++) {
      final List<double> row = rows[index];
      final double a = row[0];

      axis[index] = a;
      eccentricity[index] = row[1];
      anomaly[index] = row[5];

      // Kepler's third law: the period follows from the semi-major axis.
      motion[index] = 360.0 / (_daysPerYear * math.pow(a, 1.5).toDouble());

      final double inclination = row[2] * _degToRad;
      final double node = row[3] * _degToRad;
      final double perihelion = row[4] * _degToRad;

      final double cosNode = math.cos(node);
      final double sinNode = math.sin(node);
      final double cosPeri = math.cos(perihelion);
      final double sinPeri = math.sin(perihelion);
      final double cosInc = math.cos(inclination);
      final double sinInc = math.sin(inclination);

      orbitX[index * 3] = cosPeri * cosNode - sinPeri * sinNode * cosInc;
      orbitX[index * 3 + 1] = cosPeri * sinNode + sinPeri * cosNode * cosInc;
      orbitX[index * 3 + 2] = sinPeri * sinInc;

      orbitY[index * 3] = -sinPeri * cosNode - cosPeri * sinNode * cosInc;
      orbitY[index * 3 + 1] = -sinPeri * sinNode + cosPeri * cosNode * cosInc;
      orbitY[index * 3 + 2] = cosPeri * sinInc;
    }

    return AsteroidBelt._(
      semiMajorAxis: axis,
      eccentricity: eccentricity,
      meanMotion: motion,
      meanAnomalyAtEpoch: anomaly,
      orbitX: orbitX,
      orbitY: orbitY,
    );
  }

  /// Update [positions] for [daysSinceJ2000].
  ///
  /// An asteroid takes years to go round, so recomputing on every frame would
  /// be wasted work; the result only changes once the clock has moved enough
  /// to show.
  void updatePositions(double daysSinceJ2000, {double tolerance = 0.2}) {
    if (!_computedAtDay.isNaN &&
        (daysSinceJ2000 - _computedAtDay).abs() < tolerance) {
      return;
    }
    _computedAtDay = daysSinceJ2000;

    for (int index = 0; index < count; index++) {
      final double e = eccentricity[index];
      final double a = semiMajorAxis[index];

      double mean = (meanAnomalyAtEpoch[index] +
              meanMotion[index] * daysSinceJ2000) %
          360.0;
      if (mean > 180.0) {
        mean -= 360.0;
      } else if (mean < -180.0) {
        mean += 360.0;
      }
      final double meanRadians = mean * _degToRad;

      // Newton-Raphson on M = E - e sin E. Belt eccentricities are small, so
      // four passes are past convergence.
      double anomaly = meanRadians;
      for (int step = 0; step < 4; step++) {
        final double sine = math.sin(anomaly);
        final double cosine = math.cos(anomaly);
        anomaly -= (anomaly - e * sine - meanRadians) / (1.0 - e * cosine);
      }

      final double x = a * (math.cos(anomaly) - e);
      final double y = a * math.sqrt(1.0 - e * e) * math.sin(anomaly);

      positions[index * 3] = orbitX[index * 3] * x + orbitY[index * 3] * y;
      positions[index * 3 + 1] =
          orbitX[index * 3 + 1] * x + orbitY[index * 3 + 1] * y;
      positions[index * 3 + 2] =
          orbitX[index * 3 + 2] * x + orbitY[index * 3 + 2] * y;
    }
  }
}
