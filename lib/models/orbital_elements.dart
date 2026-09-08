import 'dart:math' as math;

/// Classical Keplerian elements for a body, with their linear rates of change.
///
/// Values are referred to the J2000 ecliptic and equinox. Rates are per Julian
/// century from J2000, matching the form published in the Jet Propulsion
/// Laboratory's table of approximate positions for the major planets, which is
/// intended for the interval 1800-2050.
class OrbitalElements {
  const OrbitalElements({
    required this.semiMajorAxisAu,
    required this.eccentricity,
    required this.inclinationDeg,
    required this.meanLongitudeDeg,
    required this.longitudeOfPerihelionDeg,
    required this.longitudeOfAscendingNodeDeg,
    this.semiMajorAxisRate = 0.0,
    this.eccentricityRate = 0.0,
    this.inclinationRate = 0.0,
    this.meanLongitudeRate = 0.0,
    this.longitudeOfPerihelionRate = 0.0,
    this.longitudeOfAscendingNodeRate = 0.0,
  });

  /// Semi-major axis, in astronomical units.
  final double semiMajorAxisAu;

  /// Orbit shape, from 0 (circular) toward 1 (parabolic).
  final double eccentricity;

  /// Tilt of the orbital plane against the ecliptic, in degrees.
  final double inclinationDeg;

  /// Mean longitude at the epoch, in degrees.
  final double meanLongitudeDeg;

  /// Longitude of perihelion, in degrees.
  final double longitudeOfPerihelionDeg;

  /// Longitude of the ascending node, in degrees.
  final double longitudeOfAscendingNodeDeg;

  final double semiMajorAxisRate;
  final double eccentricityRate;
  final double inclinationRate;
  final double meanLongitudeRate;
  final double longitudeOfPerihelionRate;
  final double longitudeOfAscendingNodeRate;

  /// The elements advanced by [centuries] Julian centuries from the epoch.
  OrbitalElements atCenturies(double centuries) {
    return OrbitalElements(
      semiMajorAxisAu: semiMajorAxisAu + semiMajorAxisRate * centuries,
      eccentricity: eccentricity + eccentricityRate * centuries,
      inclinationDeg: inclinationDeg + inclinationRate * centuries,
      meanLongitudeDeg: meanLongitudeDeg + meanLongitudeRate * centuries,
      longitudeOfPerihelionDeg:
          longitudeOfPerihelionDeg + longitudeOfPerihelionRate * centuries,
      longitudeOfAscendingNodeDeg:
          longitudeOfAscendingNodeDeg + longitudeOfAscendingNodeRate * centuries,
    );
  }

  /// Argument of perihelion, in degrees.
  double get argumentOfPerihelionDeg =>
      longitudeOfPerihelionDeg - longitudeOfAscendingNodeDeg;

  /// Mean anomaly in degrees, wrapped to the range -180 to 180.
  double get meanAnomalyDeg {
    final double raw = meanLongitudeDeg - longitudeOfPerihelionDeg;
    final double wrapped = (raw + 180.0) % 360.0;
    return (wrapped < 0 ? wrapped + 360.0 : wrapped) - 180.0;
  }

  /// Orbital period in days, from Kepler's third law.
  ///
  /// Only valid for bodies orbiting the Sun; moons carry an explicit period.
  double get siderealPeriodDays =>
      365.256363004 * math.pow(semiMajorAxisAu, 1.5).toDouble();
}
