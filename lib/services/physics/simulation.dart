import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../../models/body_catalog.dart';
import '../../models/celestial_body.dart';
import '../../models/surface_feature.dart';
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
  ///
  /// Earth is a special case, and deliberately so: it is the one body whose
  /// geography a person can check against their own window. Its angle is
  /// solved so the Sun stands over the right meridian rather than counted from
  /// an arbitrary zero — see [earthSpinRadians].
  double spinRadians(CelestialBody body) {
    if (body.key == BodyCatalog.earth.key) {
      return earthSpinRadians();
    }
    if (body.rotationHours == 0) {
      return 0.0;
    }
    final double turns = daysSinceJ2000 * 24.0 / body.rotationHours;
    return (turns % 1.0) * 2.0 * math.pi;
  }

  /// Longitude, east of Greenwich, with the Sun directly overhead.
  ///
  /// Noon UTC puts it near the prime meridian and midnight near the date line,
  /// turning fifteen degrees an hour. The equation of time is the correction
  /// for Earth's orbit being an ellipse and its axis being tilted, which runs
  /// the real Sun up to a quarter of an hour ahead of or behind the clock —
  /// four degrees of longitude, and the difference between the Sun standing
  /// over Delhi and over its suburbs.
  double get subsolarLongitudeDeg {
    final DateTime utc = time.toUtc();
    final double hours = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;

    final int dayOfYear =
        utc.difference(DateTime.utc(utc.year, 1, 1)).inDays + 1;
    final double b = 2.0 * math.pi * (dayOfYear - 81) / 364.0;
    final double equationOfTimeMinutes =
        9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);

    return _wrapDegrees(15.0 * (12.0 - (hours + equationOfTimeMinutes / 60.0)));
  }

  /// The angle to spin Earth so that [subsolarLongitudeDeg] faces the Sun.
  ///
  /// Counting turns from an epoch would be simpler, but it only keeps the
  /// right face toward the Sun if the rotation period, the epoch and the orbit
  /// all agree to the minute; they do not, and the error grows without bound.
  /// Solving for the angle instead makes it true at every instant by
  /// construction, and the planet still turns once a day because the Sun's
  /// apparent position does.
  double earthSpinRadians() {
    final Vector3 ecliptic = heliocentricPosition(BodyCatalog.earth);
    if (ecliptic.length2 < 1e-12) {
      return 0.0;
    }

    // Ecliptic coordinates are z-up and the scene is y-up, matching the
    // transform the painter places bodies with.
    final Vector3 scene = Vector3(ecliptic.x, ecliptic.z, -ecliptic.y);
    final Vector3 toSun = -scene.normalized();

    // The model matrix is a tilt about x, then the spin about y, so undo the
    // tilt before reading off which meridian the Sun stands over.
    final double tilt = BodyCatalog.earth.axialTiltDeg * math.pi / 180.0;
    final Matrix3 untilt = Matrix3.rotationX(tilt);
    final Vector3 inFrame = untilt.transformed(toSun);

    // Read the Sun's meridian with the same mapping the maps are wrapped
    // with, so the two cannot disagree about which way east runs.
    final double sunMeridian = SurfaceFeature.longitudeOf(inFrame);
    final double spin = (sunMeridian - subsolarLongitudeDeg) * math.pi / 180.0;
    return spin % (2.0 * math.pi);
  }

  static double _wrapDegrees(double degrees) =>
      (degrees + 180.0) % 360.0 - 180.0;
}
