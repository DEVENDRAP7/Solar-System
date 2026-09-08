import 'orbital_elements.dart';

/// What kind of object a body is, which drives how it is rendered and
/// described.
enum BodyType { star, terrestrial, gasGiant, iceGiant, moon }

/// A body in the simulation: its physical data, its orbit and its model.
class CelestialBody {
  const CelestialBody({
    required this.key,
    required this.label,
    required this.type,
    required this.radiusKm,
    required this.rotationHours,
    required this.axialTiltDeg,
    required this.description,
    this.elements,
    this.parentKey,
    this.orbitalPeriodDaysOverride,
    this.moonCount = 0,
    this.gravity,
    this.meanTemperatureC,
    this.ringModelAsset,
    this.ringInnerRadii = 0.0,
    this.ringOuterRadii = 0.0,
  });

  /// Stable identifier, matching the model file name.
  final String key;

  final String label;
  final BodyType type;

  /// Mean radius in kilometres.
  final double radiusKm;

  /// Sidereal rotation period in hours. Negative means retrograde.
  final double rotationHours;

  /// Tilt of the rotation axis against the orbital plane, in degrees.
  final double axialTiltDeg;

  final String description;

  /// Orbit around [parentKey], or around the Sun when that is null. The Sun
  /// itself has no elements.
  final OrbitalElements? elements;

  /// Key of the body this one orbits, or null for the Sun and the planets.
  final String? parentKey;

  /// Explicit orbital period for bodies where Kepler's third law in solar
  /// units does not apply, such as moons.
  final double? orbitalPeriodDaysOverride;

  final int moonCount;

  /// Surface gravity in m/s².
  final double? gravity;

  /// Mean surface (or cloud-top) temperature in Celsius.
  final double? meanTemperatureC;

  /// Model for a ring system, if the body has one.
  final String? ringModelAsset;

  /// Ring extent, in multiples of the body's radius.
  final double ringInnerRadii;
  final double ringOuterRadii;

  /// Asset path of the body's model.
  String get modelAsset => 'assets/models/$key.glb';

  /// Orbital period in days, from the explicit value or Kepler's third law.
  double? get orbitalPeriodDays =>
      orbitalPeriodDaysOverride ?? elements?.siderealPeriodDays;

  bool get isStar => type == BodyType.star;
  bool get orbitsSun => elements != null && parentKey == null;
}
