import 'package:vector_math/vector_math_64.dart';

import '../../models/body_catalog.dart';
import '../../models/celestial_body.dart';
import 'kepler.dart';

/// Drives the clock and computes where everything is.
///
/// Time is held as a Julian date in a double rather than a [DateTime] so that
/// large time scales stay smooth: at 10,000 days per second a millisecond
/// frame still advances the clock by a well-resolved amount.
class SolarSystemSimulation {
  SolarSystemSimulation({DateTime? start})
      : _julianDate = Kepler.julianDate(start ?? DateTime.now());

  double _julianDate;

  /// Simulated days that pass for each real second. 1.0 is real time.
  double daysPerSecond = 1.0;

  bool paused = false;

  /// The simulated instant.
  DateTime get time => DateTime.fromMillisecondsSinceEpoch(
        ((_julianDate - 2440587.5) * Duration.millisecondsPerDay).round(),
        isUtc: true,
      );

  set time(DateTime value) => _julianDate = Kepler.julianDate(value);

  double get julianDate => _julianDate;

  /// Julian centuries past J2000 at the current instant.
  double get centuries =>
      (_julianDate - Kepler.j2000JulianDate) / Kepler.daysPerCentury;

  /// Days past J2000 at the current instant.
  double get daysSinceJ2000 => _julianDate - Kepler.j2000JulianDate;

  /// Advance the clock by [deltaSeconds] of real time.
  void advance(double deltaSeconds) {
    if (paused) {
      return;
    }
    _julianDate += deltaSeconds * daysPerSecond;
  }

  /// Reset the clock to the present moment.
  void resetToNow() => time = DateTime.now();

  /// Heliocentric position of [body] in astronomical units.
  ///
  /// A moon's own elements are relative to its parent, so its heliocentric
  /// position is the parent's position plus that offset.
  Vector3 heliocentricPosition(CelestialBody body) {
    final orbit = body.elements;
    if (orbit == null) {
      return Vector3.zero();
    }

    final Vector3 local = Kepler.position(orbit, centuries);
    final String? parentKey = body.parentKey;
    if (parentKey == null) {
      return local;
    }

    final CelestialBody? parent = BodyCatalog.byKey(parentKey);
    if (parent == null) {
      return local;
    }
    return heliocentricPosition(parent) + local;
  }

  /// Position of [body] relative to its parent, in astronomical units.
  Vector3 relativePosition(CelestialBody body) {
    final orbit = body.elements;
    if (orbit == null) {
      return Vector3.zero();
    }
    return Kepler.position(orbit, centuries);
  }

  /// Heliocentric positions of every body, keyed by body key.
  Map<String, Vector3> positions() {
    return <String, Vector3>{
      for (final CelestialBody body in BodyCatalog.all)
        body.key: heliocentricPosition(body),
    };
  }

  /// Rotation of [body] about its own axis, in radians from 0 to 2*pi.
  ///
  /// A negative rotation period winds the angle backwards as time advances,
  /// which is what makes Venus and Uranus spin the other way.
  double spinRadians(CelestialBody body) {
    if (body.rotationHours == 0) {
      return 0.0;
    }
    final double turns = daysSinceJ2000 * 24.0 / body.rotationHours;
    return (turns % 1.0) * 2.0 * 3.141592653589793;
  }
}
