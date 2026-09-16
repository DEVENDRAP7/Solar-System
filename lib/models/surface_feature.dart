import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// A named place on a body: a crater, a sea, a mountain, a canyon.
class SurfaceFeature {
  const SurfaceFeature({
    required this.bodyKey,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.diameterKm,
    this.kind = '',
  });

  final String bodyKey;
  final String name;

  /// Degrees north of the equator.
  final double latitude;

  /// Degrees east, as the gazetteer gives them.
  final double longitude;

  /// How far across the feature is. Labels are shown largest first, so this is
  /// what decides which names survive when there is no room for all of them.
  final double diameterKm;

  /// The gazetteer's own word for it: Crater, Mare, Mons, Vallis and so on.
  final String kind;

  /// Where the feature sits on a unit sphere, in the mesh's own frame.
  Vector3 get direction => directionFor(latitude, longitude);

  /// The point on a body's unit sphere at a given latitude and longitude.
  ///
  /// The one place this mapping is written down. Every map in the app is
  /// wrapped the same way, and east on them runs toward the mesh's -z. The
  /// sign is easy to get wrong and impossible to see at longitude zero, which
  /// is exactly where anyone would check it: backwards leaves Greenwich right
  /// and everywhere else mirrored.
  static Vector3 directionFor(double latitudeDeg, double longitudeDeg) {
    final double lat = latitudeDeg * math.pi / 180.0;
    final double lon = longitudeDeg * math.pi / 180.0;
    final double cosLat = math.cos(lat);
    return Vector3(
      cosLat * math.cos(lon),
      math.sin(lat),
      -cosLat * math.sin(lon),
    );
  }

  /// The longitude of a direction in the mesh's frame, in degrees: the inverse
  /// of [directionFor].
  static double longitudeOf(Vector3 direction) =>
      math.atan2(-direction.z, direction.x) * 180.0 / math.pi;

  /// Parse the gazetteer export.
  ///
  /// Columns: body, name, lat, lon, diameter_km, kind.
  static List<SurfaceFeature> parse(String csv) {
    final List<SurfaceFeature> features = <SurfaceFeature>[];
    final List<String> lines = csv.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i].trim();
      if (line.isEmpty || (i == 0 && line.startsWith('body'))) {
        continue;
      }
      final List<String> cells = _splitRow(line);
      if (cells.length < 5) {
        continue;
      }
      final double? lat = double.tryParse(cells[2]);
      final double? lon = double.tryParse(cells[3]);
      final double? diameter = double.tryParse(cells[4]);
      if (lat == null || lon == null || diameter == null) {
        continue;
      }
      features.add(
        SurfaceFeature(
          bodyKey: cells[0].trim().toLowerCase(),
          name: cells[1].trim(),
          latitude: lat,
          longitude: lon,
          diameterKm: diameter,
          kind: cells.length > 5 ? cells[5].trim() : '',
        ),
      );
    }
    return features;
  }

  /// Split one CSV row, honouring quoted cells — several feature names have a
  /// comma in them.
  static List<String> _splitRow(String line) {
    final List<String> cells = <String>[];
    final StringBuffer cell = StringBuffer();
    bool quoted = false;

    for (int i = 0; i < line.length; i++) {
      final String character = line[i];
      if (character == '"') {
        quoted = !quoted;
      } else if (character == ',' && !quoted) {
        cells.add(cell.toString());
        cell.clear();
      } else {
        cell.write(character);
      }
    }
    cells.add(cell.toString());
    return cells;
  }
}
