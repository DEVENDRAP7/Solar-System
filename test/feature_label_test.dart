import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/models/surface_feature.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:solar_system_app/services/render/star_field.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

void main() {
  group('where a named place sits on the globe', () {
    test('the equator and prime meridian point along +x', () {
      const SurfaceFeature origin = SurfaceFeature(
        bodyKey: 'moon',
        name: 'origin',
        latitude: 0,
        longitude: 0,
        diameterKm: 1,
      );
      expect(origin.direction.x, closeTo(1.0, 1e-9));
      expect(origin.direction.y, closeTo(0.0, 1e-9));
      expect(origin.direction.z, closeTo(0.0, 1e-9));
    });

    test('the north pole points along +y, whatever the longitude', () {
      for (final double lon in <double>[-180, -90, 0, 90, 180]) {
        final SurfaceFeature pole = SurfaceFeature(
          bodyKey: 'moon',
          name: 'pole',
          latitude: 90,
          longitude: lon,
          diameterKm: 1,
        );
        expect(pole.direction.y, closeTo(1.0, 1e-9));
      }
    });

    test('east runs toward -z, the way the maps are wrapped', () {
      const SurfaceFeature east = SurfaceFeature(
        bodyKey: 'moon',
        name: 'east',
        latitude: 0,
        longitude: 90,
        diameterKm: 1,
      );
      // Not +z, which is what this test asserted until a render of Earth
      // showed the Americas facing the Sun at a moment India should have
      // been. The sign is invisible at longitude zero — Greenwich came out
      // right either way — and mirrors everything else.
      expect(east.direction.z, closeTo(-1.0, 1e-9));
    });

    test('the mapping round-trips', () {
      for (final double longitude in <double>[-170, -90, -12, 0, 45, 78, 179]) {
        expect(
          SurfaceFeature.longitudeOf(
            SurfaceFeature.directionFor(20.0, longitude),
          ),
          closeTo(longitude, 1e-9),
          reason: 'longitude $longitude',
        );
      }
    });

    test('every direction is a unit vector', () {
      for (final SurfaceFeature feature in SurfaceFeature.parse(
        File('assets/data/features.csv').readAsStringSync(),
      )) {
        expect(
          feature.direction.length,
          closeTo(1.0, 1e-9),
          reason: feature.name,
        );
      }
    });
  });

  test('the shipped names parse, and cover the bodies worth naming', () {
    final List<SurfaceFeature> features = SurfaceFeature.parse(
      File('assets/data/features.csv').readAsStringSync(),
    );

    expect(features.length, greaterThan(80));
    final Set<String> bodies = features
        .map((SurfaceFeature f) => f.bodyKey)
        .toSet();
    for (final String key in <String>['moon', 'mars', 'mercury', 'venus']) {
      expect(bodies, contains(key));
    }
    // Every name belongs to a body the app actually draws, or it can never
    // appear however right the coordinates are.
    for (final String key in bodies) {
      expect(BodyCatalog.byKey(key), isNotNull, reason: key);
    }
    // Latitudes and longitudes in range.
    for (final SurfaceFeature feature in features) {
      expect(
        feature.latitude.abs(),
        lessThanOrEqualTo(90.0),
        reason: feature.name,
      );
      expect(
        feature.longitude,
        inInclusiveRange(-360.0, 360.0),
        reason: feature.name,
      );
    }
  });

  testWidgets('names are drawn, and only when there is room for them', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
      for (final CelestialBody body in BodyCatalog.all) {
        meshes[body.key] = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );
      }
      final Map<String, List<SurfaceFeature>> named =
          <String, List<SurfaceFeature>>{};
      for (final SurfaceFeature feature in SurfaceFeature.parse(
        File('assets/data/features.csv').readAsStringSync(),
      )) {
        named
            .putIfAbsent(feature.bodyKey, () => <SurfaceFeature>[])
            .add(feature);
      }

      Future<int> brightPixels({
        required bool labels,
        required double distance,
      }) async {
        const ui.Size size = ui.Size(600, 600);
        final vm.Vector3 at = bodyWorldPosition(
          SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
          const ViewScale(),
          BodyCatalog.moon,
        );
        final double sunward = math.atan2(at.x, at.z);

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        SolarSystemPainter(
          simulation: SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
          camera: OrbitCamera(
            target: at,
            distance: distance,
            yaw: math.atan2(math.cos(sunward), -math.sin(sunward)),
            pitch: 0.0,
          ),
          meshes: meshes,
          scale: const ViewScale(),
          stars: <StarBand>[],
          hits: <BodyHit>[],
          showOrbits: false,
          showMoons: true,
          belt: null,
          showBelt: false,
          features: named,
          showLabels: labels,
          repaint: ValueNotifier<int>(0),
        ).paint(ui.Canvas(recorder), size);

        final ui.Image image = await recorder.endRecording().toImage(600, 600);
        final Uint8List pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();

        // Label text is a cool near-white; the Moon's rock is neutral grey.
        // Counting bright pixels that are distinctly blue separates letters
        // from landscape, which simple brightness cannot do on a body this
        // pale.
        int bright = 0;
        for (int i = 0; i < pixels.length; i += 4) {
          final int red = pixels[i];
          final int blue = pixels[i + 2];
          if (blue > 190 && blue - red > 10) {
            bright++;
          }
        }
        return bright;
      }

      final int withNames = await brightPixels(labels: true, distance: 0.9);
      final int without = await brightPixels(labels: false, distance: 0.9);
      final int farOff = await brightPixels(labels: true, distance: 60.0);

      expect(
        withNames,
        greaterThan(without + 200),
        reason: 'names should put ink on the screen',
      );
      expect(
        farOff,
        lessThan(without + 200),
        reason: 'a body a few pixels across should carry no place names',
      );
    });
  });
}
