import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/asteroid_belt.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:solar_system_app/services/render/star_field.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// The scene is transformed and lit in Dart, a vertex at a time, so the cost of
/// a frame rises with how finely the bodies are modelled. This is here to keep
/// that honest: the phone has 16 ms to work with.
void main() {
  testWidgets('a frame of the opening view stays well inside a phone frame', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
      int triangles = 0;
      for (final CelestialBody body in BodyCatalog.all) {
        final MeshAsset mesh = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );
        meshes[body.key] = mesh;
        triangles += mesh.triangleCount;
        final String? ring = body.ringModelAsset;
        if (ring != null) {
          meshes[ring.split('/').last.replaceAll('.glb', '')] =
              await GlbReader.parse(await File(ring).readAsBytes());
        }
      }

      final AsteroidBelt belt = AsteroidBelt.parse(
        File('assets/data/asteroids.csv').readAsStringSync(),
      );
      final List<StarBand> stars = StarField.banded(StarField.make(2600));

      double paint(OrbitCamera camera, int frames) {
        final Stopwatch clock = Stopwatch()..start();
        for (int i = 0; i < frames; i++) {
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          SolarSystemPainter(
            simulation: SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
            camera: camera,
            meshes: meshes,
            scale: const ViewScale(),
            stars: stars,
            hits: <BodyHit>[],
            showOrbits: true,
            showMoons: true,
            belt: belt,
            repaint: ValueNotifier<int>(0),
          ).paint(ui.Canvas(recorder), const ui.Size(1080, 2340));
          recorder.endRecording().dispose();
        }
        return clock.elapsedMicroseconds / frames / 1000.0;
      }

      // Warm up, then measure.
      paint(OrbitCamera.overview(), 3);
      final double overview = paint(OrbitCamera.overview(), 20);

      final vm.Vector3 jupiter = bodyWorldPosition(
        SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
        const ViewScale(),
        BodyCatalog.jupiter,
      );
      final double closeUp = paint(
        OrbitCamera(target: jupiter, distance: 7.5, yaw: 0.5, pitch: 0.25),
        20,
      );

      debugPrint('PERF $triangles triangles across ${meshes.length} meshes');
      debugPrint('PERF overview ${overview.toStringAsFixed(2)} ms/frame');
      debugPrint('PERF close-up ${closeUp.toStringAsFixed(2)} ms/frame');

      // Generous, because a test machine is not a phone — this is a tripwire
      // for a change that makes the scene an order of magnitude dearer, not a
      // measurement of the device.
      expect(overview, lessThan(40.0));
      expect(closeUp, lessThan(40.0));
    });
  });
}
