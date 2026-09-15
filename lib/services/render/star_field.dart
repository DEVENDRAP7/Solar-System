import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:vector_math/vector_math_64.dart';

/// One star: where it is on the sky, and what it looks like.
class Star {
  const Star(this.direction, this.size, this.colour);

  /// Unit direction from the camera.
  final Vector3 direction;

  /// Radius in pixels.
  final double size;

  final ui.Color colour;
}

/// A band of stars drawn at one size and colour, so the whole sky is a
/// handful of draw calls rather than one per star.
class StarBand {
  StarBand(this.size, this.colour);

  final double size;
  final ui.Color colour;
  final List<Vector3> directions = <Vector3>[];
}

/// Builds the night sky.
///
/// The old field was one size and one colour, which reads as salt spilled on
/// black. A real sky has a steep brightness distribution — a handful of bright
/// stars and a great many faint ones — colours running from blue-white to
/// amber, and the Milky Way, which is not a band of brighter stars but of very
/// many more of them.
class StarField {
  const StarField._();

  /// Colours by spectral class, roughly: hot blue-white through to cool amber.
  static const List<ui.Color> _colours = <ui.Color>[
    ui.Color(0xFFAFC8FF),
    ui.Color(0xFFD7E3FF),
    ui.Color(0xFFFFFFFF),
    ui.Color(0xFFFFF3DC),
    ui.Color(0xFFFFD9A8),
  ];

  /// How far off the galactic plane the Milky Way's stars scatter, in radians.
  static const double _bandSpread = 0.20;

  /// The share of stars that belong to the Milky Way rather than the whole sky.
  static const double _bandShare = 0.55;

  /// Tilt of the galactic plane against the ecliptic. The real angle is about
  /// 60 degrees, which is why the Milky Way crosses the sky at a slant rather
  /// than lying along the planets' orbits.
  static const double _galacticTilt = 60.0 * math.pi / 180.0;

  static List<Star> make(int count, {int seed = 20260908}) {
    final math.Random random = math.Random(seed);
    final List<Star> stars = <Star>[];

    for (int i = 0; i < count; i++) {
      final bool inBand = random.nextDouble() < _bandShare;
      stars.add(
        Star(
          inBand ? _bandDirection(random) : _anyDirection(random),
          _size(random),
          _colours[random.nextInt(_colours.length)],
        ),
      );
    }
    return stars;
  }

  /// Group stars into a few bands so drawing them is a few calls.
  static List<StarBand> banded(List<Star> stars) {
    final Map<String, StarBand> bands = <String, StarBand>{};
    for (final Star star in stars) {
      // Round the size so near-identical stars share a call.
      final double size = (star.size * 2).round() / 2;
      final String key = '$size/${star.colour.toARGB32()}';
      bands
          .putIfAbsent(key, () => StarBand(size, star.colour))
          .directions
          .add(star.direction);
    }
    final List<StarBand> out = bands.values.toList();
    // Faintest first, so the bright ones are not buried under the crowd.
    out.sort((StarBand a, StarBand b) => a.size.compareTo(b.size));
    return out;
  }

  /// A steep distribution: mostly faint, a few bright.
  static double _size(math.Random random) {
    final double roll = random.nextDouble();
    return 0.7 + 2.0 * roll * roll * roll * roll;
  }

  static Vector3 _anyDirection(math.Random random) {
    final double u = random.nextDouble() * 2.0 - 1.0;
    final double theta = random.nextDouble() * 2.0 * math.pi;
    final double r = math.sqrt(1.0 - u * u);
    return Vector3(r * math.cos(theta), u, r * math.sin(theta));
  }

  /// A direction near the galactic plane.
  static Vector3 _bandDirection(math.Random random) {
    final double along = random.nextDouble() * 2.0 * math.pi;
    // Two draws summed give a soft-edged band rather than a hard-edged strip.
    final double off =
        (random.nextDouble() + random.nextDouble() - 1.0) * _bandSpread;

    final Vector3 inPlane = Vector3(
      math.cos(along) * math.cos(off),
      math.sin(off),
      math.sin(along) * math.cos(off),
    );

    // Tilt the whole plane off the ecliptic.
    final double c = math.cos(_galacticTilt);
    final double s = math.sin(_galacticTilt);
    return Vector3(
      inPlane.x,
      inPlane.y * c - inPlane.z * s,
      inPlane.y * s + inPlane.z * c,
    )..normalize();
  }
}
