import 'dart:ui' show Color;

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
    this.atmosphere,
    this.atmosphereDepth = 0.055,
  });

  /// Colour of the body's air, seen edge-on against space, or null for a body
  /// with none. It is what gives a planet a soft rim instead of a hard edge —
  /// the giveaway, at a glance, between a world and a billiard ball.
  final Color? atmosphere;

  /// How far the air reaches past the surface, as a fraction of the radius.
  /// Exaggerated: Earth's is nearer 1%, which would be a single pixel.
  final double atmosphereDepth;

  /// How wide the band between day and night is, as a fraction of the angle
  /// to the Sun.
  ///
  /// An airless body has a hard edge — on the Moon you can stand with one foot
  /// in each. Air scatters light round the limb, and the thicker it is the
  /// further round it reaches, which is why Venus fades into its night side
  /// over tens of degrees and Mercury does not.
  double get terminatorWidth =>
      atmosphere == null ? 0.06 : 0.10 + atmosphereDepth * 2.5;

  /// Stable identifier, matching the model file name.
  final String key;

  final String label;
  final BodyType type;

  /// Mean radius in kilometres.
  final double radiusKm;

  /// Sidereal rotation period in hours. Negative means retrograde.
  final double rotationHours;

  /// Tilt of the rotation axis against the orbital plane, in degrees.
  ///
  /// Applied as a lean about the scene's x axis, which points the north pole
  /// toward ecliptic longitude 270 — where Earth's really points. Leaning it
  /// the other way costs nothing at a glance and everything in June: the Sun
  /// would stand over the equator at the solstice and over a tropic at the
  /// equinox, and the seasons would run a quarter of a year late.
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
