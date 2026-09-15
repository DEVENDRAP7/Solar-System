import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/asteroid_belt.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/body_inspector.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:solar_system_app/services/render/star_field.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// The moment every frame here is taken at. The clock is held while a finger
/// is down, so turning a planet never advances time.
final DateTime _instant = DateTime.utc(2026, 9, 9);

Future<ui.Image> frame(
  Map<String, MeshAsset> meshes, {
  required OrbitCamera camera,
  required BodyInspector inspector,
  required AsteroidBelt belt,
  ui.Size size = const ui.Size(720, 1280),
}) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  SolarSystemPainter(
    simulation: SolarSystemSimulation(start: _instant),
    camera: camera,
    meshes: meshes,
    scale: const ViewScale(),
    // A fixed seed would be nicer, but the same list is shared by both frames,
    // which is what matters: the stars are identical either way.
    stars: _stars,
    hits: <BodyHit>[],
    showOrbits: true,
    showMoons: true,
    belt: belt,
    inspector: inspector,
    repaint: ValueNotifier<int>(0),
  ).paint(canvas, size);

  return recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
}

final List<StarBand> _stars = StarField.banded(StarField.make(2600));

Future<Uint8List> pixels(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

void main() {
  testWidgets('turning a planet leaves everything behind it untouched', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
      for (final CelestialBody body in BodyCatalog.all) {
        meshes[body.key] = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );
        final String? ring = body.ringModelAsset;
        if (ring != null) {
          meshes[ring.split('/').last.replaceAll('.glb', '')] =
              await GlbReader.parse(await File(ring).readAsBytes());
        }
      }
      final AsteroidBelt belt = AsteroidBelt.parse(
        File('assets/data/asteroids.csv').readAsStringSync(),
      );

      const ui.Size size = ui.Size(720, 1280);
      final vm.Vector3 earth = bodyWorldPosition(
        SolarSystemSimulation(start: _instant),
        const ViewScale(),
        BodyCatalog.earth,
      );

      // The camera the app uses once Earth is selected, held still across both
      // frames — which is the whole point: only the inspector changes.
      OrbitCamera camera() => OrbitCamera(
        target: earth.clone(),
        distance: 2.4,
        yaw: 0.5,
        pitch: 0.25,
      );

      final BodyInspector square = BodyInspector()..focus('earth');
      final BodyInspector turned = BodyInspector()..focus('earth');
      turned.turn(1.4, 0.0);

      final Uint8List before = await pixels(
        await frame(meshes, camera: camera(), inspector: square, belt: belt),
      );
      final Uint8List after = await pixels(
        await frame(meshes, camera: camera(), inspector: turned, belt: belt),
      );

      // Earth fills the middle of the frame. Everything further out than this
      // is background: other planets, the orbit rings, the belt, the stars.
      final double focal = camera().focalLength(size.width, size.height);
      final double discRadius =
          focal *
          const ViewScale().bodyRadius(BodyCatalog.earth.radiusKm) /
          2.4;
      final double outside = discRadius + 24;
      final ui.Offset centre = ui.Offset(size.width / 2, size.height / 2);

      int backgroundChanged = 0;
      int discChanged = 0;

      for (int y = 0; y < size.height.toInt(); y++) {
        for (int x = 0; x < size.width.toInt(); x++) {
          final int i = (y * size.width.toInt() + x) * 4;
          final bool same =
              before[i] == after[i] &&
              before[i + 1] == after[i + 1] &&
              before[i + 2] == after[i + 2];
          if (same) {
            continue;
          }
          final double r = math.sqrt(
            math.pow(x - centre.dx, 2) + math.pow(y - centre.dy, 2),
          );
          if (r > outside) {
            backgroundChanged++;
          } else {
            discChanged++;
          }
        }
      }

      expect(
        backgroundChanged,
        0,
        reason: 'the sky behind the planet must not move when it is turned',
      );
      expect(
        discChanged,
        greaterThan(2000),
        reason: 'the planet itself must actually have turned',
      );
    });
  });
}
