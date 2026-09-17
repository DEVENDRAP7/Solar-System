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
  static const double _earthOrbitUnits = 17.0;

  /// Compression exponent for orbital distance.
  ///
  /// Lower compresses the outer system harder; higher spreads the inner
  /// planets apart. This is the knob that decides whether the inner system
  /// looks crowded, and it was set too low: Earth's disc came out 1.1 units
  /// across sitting in a 1.5-unit gap between its neighbours' orbits, so the
  /// four inner planets nearly touched. The cost of raising it is that the
  /// whole system is wider and every body is therefore smaller on screen.
  static const double _distanceExponent = 0.52;

  /// Scene units for Earth's radius in [ScaleMode.explore].
  static const double _earthRadiusUnits = 0.70;

  /// Compression exponent for body radius.
  ///
  /// A cube root flattened the bodies into near-uniformity: Jupiter came out
  /// 2.2 times Earth when it is really 11, and Mercury 0.73 when it is 0.38.
  /// A square root keeps everything on one screen while letting a giant look
  /// like a giant — Jupiter 3.3 times Earth, Mercury 0.62.
  static const double _radiusExponent = 0.5;

  /// Mercury's semi-major axis, which sets how much room the Sun has.
  static const double _mercuryOrbitAu = 0.387;

  /// The most of Mercury's orbit the Sun's disc may fill.
  ///
  /// The Sun is 109 times Earth's radius and would be drawn at ten times
  /// Jupiter — far outside Mercury's orbit, swallowing the inner system. It is
  /// held here instead, which is still a wild exaggeration: in life the Sun
  /// spans about one part in eighty of that orbit, not two fifths.
  static const double _starShareOfInnerOrbit = 0.40;

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
        final double drawn =
            _earthRadiusUnits *
            factor *
            math.pow(radiusKm / _earthRadiusKm, _radiusExponent).toDouble();
        // The Sun is on a different order from everything else and is the one
        // body the shared rule cannot hold.
        return math.min(drawn, _starCeiling);
      case ScaleMode.trueScale:
        return _trueUnitsPerAu * radiusKm / _kmPerAu;
    }
  }

  /// The largest any body is drawn: how far the Sun may reach toward Mercury.
  double get _starCeiling => _starShareOfInnerOrbit * distance(_mercuryOrbitAu);

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
    double? neighbourhood,
    double parentRingOuterRadii = 0.0,
  }) {
    if (mode == ScaleMode.trueScale) {
      return distance(astronomicalUnits);
    }

    final double radiiOut =
        (semiMajorAxisAu * _kmPerAu) / math.max(parentRadiusKm, 1.0);
    final double placed =
        parentRadiusUnits *
        (1.45 + 1.75 * math.log(math.max(radiiOut, 1.2)) / math.ln10);

    // Keep the eccentricity visible: a moon on an oval orbit still swings in
    // and out over its month.
    final double variation = semiMajorAxisAu <= 0
        ? 1.0
        : astronomicalUnits / semiMajorAxisAu;

    final double drawn = _withinNeighbourhood(
      placed * (0.92 + 0.08 * variation.clamp(0.6, 1.4)),
      neighbourhood,
    );

    // Never inside the planet, and never inside its rings. The ring floor
    // matters because the two do not move together: rings are a fixed
    // multiple of the planet's radius, while a moon squeezed toward its
    // neighbourhood limit is not, so drawing the planets larger walks the
    // innermost moons into the rings unless this holds them out.
    final double clearOfRings = parentRingOuterRadii > 0
        ? parentRadiusUnits * parentRingOuterRadii + moonRadiusUnits
        : 0.0;

    return math.max(
      math.max(drawn, parentRadiusUnits + moonRadiusUnits * 1.5),
      clearOfRings,
    );
  }

  /// The share of the way to its nearest neighbour that a planet's moons may
  /// reach. Short of half, so that even two neighbouring systems both reaching
  /// their limit cannot meet in the middle.
  static const double _moonReach = 0.46;

  /// Where the squeeze starts, as a share of the limit. Below this a moon is
  /// left alone: compressing the whole system to fit its outermost member
  /// would push Mimas inside Saturn's rings, where it has no business being.
  static const double _squeezeFrom = 0.7;

  /// Hold a moon inside its planet's own stretch of the solar system.
  ///
  /// Moon orbits are drawn on their own scale, which is generous — the Moon
  /// sits sixty Earth radii out in life and about four here. Generous enough,
  /// it turns out, that the Moon's orbit crossed Venus's, Callisto's crossed
  /// Mars's and Iapetus's crossed Jupiter's. Nothing about the scene says
  /// those are different scales, so it reads as the planets being jumbled
  /// together.
  ///
  /// The far end is eased toward the limit rather than clipped at it, so the
  /// order of a system's moons survives and no two of them land on top of
  /// each other.
  static double _withinNeighbourhood(double placed, double? neighbourhood) {
    if (neighbourhood == null || neighbourhood <= 0) {
      return placed;
    }
    final double limit = neighbourhood * _moonReach;
    final double free = limit * _squeezeFrom;
    if (placed <= free) {
      return placed;
    }
    final double span = limit - free;
    return limit - span * math.exp(-(placed - free) / span);
  }
}
