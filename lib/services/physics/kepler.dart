import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../../models/orbital_elements.dart';

/// Solving Kepler's equation and turning elements into positions.
///
/// Positions are heliocentric (or, for a moon, relative to its parent) and
/// expressed in astronomical units on the J2000 ecliptic frame, with x toward
/// the vernal equinox and z toward the ecliptic north pole.
class Kepler {
  const Kepler._();

  static const double _degToRad = math.pi / 180.0;

  /// Julian date of the J2000.0 epoch.
  static const double j2000JulianDate = 2451545.0;

  /// Days in a Julian century.
  static const double daysPerCentury = 36525.0;

  /// Julian date for [time], which is interpreted as UTC.
  static double julianDate(DateTime time) {
    final double millis = time.toUtc().millisecondsSinceEpoch.toDouble();
    return millis / Duration.millisecondsPerDay + 2440587.5;
  }

  /// Julian centuries elapsed from J2000 to [time].
  static double centuriesSinceJ2000(DateTime time) =>
      (julianDate(time) - j2000JulianDate) / daysPerCentury;

  /// Solve `M = E - e sin E` for the eccentric anomaly, in radians.
  ///
  /// Newton-Raphson converges in a handful of iterations for the small
  /// eccentricities of the major planets.
  static double eccentricAnomaly(
    double meanAnomalyRad,
    double eccentricity, {
    double tolerance = 1e-10,
    int maxIterations = 32,
  }) {
    double anomaly = eccentricity < 0.8
        ? meanAnomalyRad
        : math.pi * (meanAnomalyRad.isNegative ? -1.0 : 1.0);

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      final double error =
          anomaly - eccentricity * math.sin(anomaly) - meanAnomalyRad;
      final double derivative = 1.0 - eccentricity * math.cos(anomaly);
      final double delta = error / derivative;
      anomaly -= delta;
      if (delta.abs() < tolerance) {
        break;
      }
    }
    return anomaly;
  }

  /// Position for [elements] at [centuries] Julian centuries past J2000.
  static Vector3 position(OrbitalElements elements, double centuries) =>
      positionFromCurrentElements(elements.atCenturies(centuries));

  /// Position from elements that have already been advanced to the epoch.
  static Vector3 positionFromCurrentElements(OrbitalElements current) {
    final double eccentricity = current.eccentricity;
    final double meanAnomaly = current.meanAnomalyDeg * _degToRad;
    final double anomaly = eccentricAnomaly(meanAnomaly, eccentricity);

    // Position in the orbital plane, perihelion along +x.
    final double a = current.semiMajorAxisAu;
    final double xOrbital = a * (math.cos(anomaly) - eccentricity);
    final double yOrbital =
        a * math.sqrt(1.0 - eccentricity * eccentricity) * math.sin(anomaly);

    return _orbitalToEcliptic(xOrbital, yOrbital, current);
  }

  /// Rotate orbital-plane coordinates into the ecliptic frame.
  static Vector3 _orbitalToEcliptic(
    double xOrbital,
    double yOrbital,
    OrbitalElements elements,
  ) {
    final double argument = elements.argumentOfPerihelionDeg * _degToRad;
    final double node = elements.longitudeOfAscendingNodeDeg * _degToRad;
    final double inclination = elements.inclinationDeg * _degToRad;

    final double cosArgument = math.cos(argument);
    final double sinArgument = math.sin(argument);
    final double cosNode = math.cos(node);
    final double sinNode = math.sin(node);
    final double cosInclination = math.cos(inclination);
    final double sinInclination = math.sin(inclination);

    final double x =
        (cosArgument * cosNode - sinArgument * sinNode * cosInclination) *
                xOrbital +
            (-sinArgument * cosNode - cosArgument * sinNode * cosInclination) *
                yOrbital;
    final double y =
        (cosArgument * sinNode + sinArgument * cosNode * cosInclination) *
                xOrbital +
            (-sinArgument * sinNode + cosArgument * cosNode * cosInclination) *
                yOrbital;
    final double z = (sinArgument * sinInclination) * xOrbital +
        (cosArgument * sinInclination) * yOrbital;

    return Vector3(x, y, z);
  }

  /// Points tracing one full orbit, for drawing the orbital path.
  ///
  /// The shape is sampled from the elements as they stand at [centuries], so a
  /// path drawn far from J2000 reflects the orbit's slow precession.
  static List<Vector3> orbitPath(
    OrbitalElements elements,
    double centuries, {
    int segments = 180,
  }) {
    final OrbitalElements current = elements.atCenturies(centuries);
    final List<Vector3> points = <Vector3>[];

    for (int index = 0; index < segments; index++) {
      final double anomaly = 2.0 * math.pi * index / segments;
      final double a = current.semiMajorAxisAu;
      final double e = current.eccentricity;
      final double xOrbital = a * (math.cos(anomaly) - e);
      final double yOrbital = a * math.sqrt(1.0 - e * e) * math.sin(anomaly);
      points.add(_orbitalToEcliptic(xOrbital, yOrbital, current));
    }
    return points;
  }
}
