import 'dart:math' as math;

/// How the simulation's real distances are mapped into the scene.
enum ScaleMode {
  /// Distances and sizes are compressed so the whole system is legible at
  /// once. Ordering and relative differences are preserved.
  explore,

  /// Everything at its true proportions. Honest, and almost entirely empty
  /// space — which is the point of offering it.
  trueScale,
}

/// Converts astronomical units and kilometres into scene units.
///
/// A solar system at literal scale cannot be drawn usefully: Neptune sits
/// 4.5 billion km out while Earth is 12,742 km across, so at any zoom that
/// shows the orbits, every planet is far below one pixel. [ScaleMode.explore]
/// compresses both axes with fractional powers, which keeps the ordering and
/// the sense of "much bigger" or "much further" while fitting on a screen.
class ViewScale {
  const ViewScale({this.mode = ScaleMode.explore});

  final ScaleMode mode;

  /// Scene units for Earth's orbital radius in [ScaleMode.explore].
  static const double _earthOrbitUnits = 12.0;

  /// Compression exponent for orbital distance.
  static const double _distanceExponent = 0.55;

  /// Scene units for Earth's radius in [ScaleMode.explore].
  static const double _earthRadiusUnits = 0.58;

  /// Compression exponent for body radius.
  static const double _radiusExponent = 1.0 / 3.0;

  static const double _earthRadiusKm = 6371.0;
  static const double _kmPerAu = 1.495978707e8;

  /// Scene units per astronomical unit in [ScaleMode.trueScale].
  static const double _trueUnitsPerAu = 40.0;

  /// Scene distance for an orbital radius given in astronomical units.
  double distance(double astronomicalUnits) {
    if (astronomicalUnits <= 0) {
      return 0.0;
    }
    switch (mode) {
      case ScaleMode.explore:
        return _earthOrbitUnits *
            math.pow(astronomicalUnits, _distanceExponent).toDouble();
      case ScaleMode.trueScale:
        return _trueUnitsPerAu * astronomicalUnits;
    }
  }

  /// How much smaller a moon is drawn than the same size planet would be.
  ///
  /// Without this the compression flatters moons: Ganymede would come out a
  /// third of Jupiter's width when it is really a twenty-seventh.
  static const double _moonScale = 0.55;

  /// Scene radius for a body of [radiusKm].
  double bodyRadius(double radiusKm, {bool isMoon = false}) {
    final double factor = isMoon ? _moonScale : 1.0;
    switch (mode) {
      case ScaleMode.explore:
        return _earthRadiusUnits *
            factor *
            math.pow(radiusKm / _earthRadiusKm, _radiusExponent).toDouble();
      case ScaleMode.trueScale:
        return _trueUnitsPerAu * radiusKm / _kmPerAu;
    }
  }

  /// Scene distance for a moon from the planet it orbits.
  ///
  /// Moons sit far closer to their planet than planets do to the Sun, so the
  /// same compression would bury them inside the surface. Instead they are
  /// placed by how many planet radii out they really orbit, on a log scale so
  /// that a system spanning Mimas at 3 radii to Iapetus at 61 all fits and
  /// stays in the right order. Mimas still comes out just beyond the rings,
  /// where it belongs.
  double satelliteDistance({
    required double astronomicalUnits,
    required double semiMajorAxisAu,
    required double parentRadiusKm,
    required double parentRadiusUnits,
    required double moonRadiusUnits,
  }) {
    if (mode == ScaleMode.trueScale) {
      return distance(astronomicalUnits);
    }

    final double radiiOut =
        (semiMajorAxisAu * _kmPerAu) / math.max(parentRadiusKm, 1.0);
    final double placed = parentRadiusUnits *
        (1.45 + 1.75 * math.log(math.max(radiiOut, 1.2)) / math.ln10);

    // Keep the eccentricity visible: a moon on an oval orbit still swings in
    // and out over its month.
    final double variation =
        semiMajorAxisAu <= 0 ? 1.0 : astronomicalUnits / semiMajorAxisAu;

    return math.max(
      placed * (0.92 + 0.08 * variation.clamp(0.6, 1.4)),
      parentRadiusUnits + moonRadiusUnits * 1.5,
    );
  }
}
