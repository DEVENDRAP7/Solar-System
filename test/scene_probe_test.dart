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
import 'package:solar_system_app/services/render/mesh_library.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// Renders the real scene to build/render_probe/ so it can be inspected.
Future<void> shoot(
  String name,
  Map<String, MeshAsset> meshes, {
  required OrbitCamera camera,
  required ViewScale scale,
  AsteroidBelt? belt,
  ui.Size size = const ui.Size(720, 1280),
  DateTime? at,
  bool showOrbits = true,
}) async {
  final SolarSystemSimulation simulation =
      SolarSystemSimulation(start: at ?? DateTime.utc(2026, 9, 9));

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  SolarSystemPainter(
    simulation: simulation,
    camera: camera,
    meshes: meshes,
    scale: scale,
    stars: MeshLibrary.makeStars(1200),
    hits: <BodyHit>[],
    showOrbits: showOrbits,
    showMoons: true,
    belt: belt,
    repaint: ValueNotifier<int>(0),
  ).paint(canvas, size);

  final ui.Image image = await recorder
      .endRecording()
      .toImage(size.width.toInt(), size.height.toInt());
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);

  final Directory out = Directory('build/render_probe')
    ..createSync(recursive: true);
  File('${out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('renders the solar system', (WidgetTester tester) async {
    await tester.runAsync(() async {
      final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
      for (final CelestialBody body in BodyCatalog.all) {
        final Uint8List bytes =
            await File(body.modelAsset).readAsBytes();
        meshes[body.key] = await GlbReader.parse(bytes);
      }
      expect(meshes.length, BodyCatalog.all.length);

      final AsteroidBelt belt = AsteroidBelt.parse(
        File('assets/data/asteroids.csv').readAsStringSync(),
      );
      expect(belt.count, greaterThan(1000));

      await shoot(
        'system',
        meshes,
        camera: OrbitCamera(distance: 40, yaw: 0.6, pitch: 0.55),
        scale: const ViewScale(),
        belt: belt,
      );

      await shoot(
        'belt',
        meshes,
        camera: OrbitCamera(distance: 85, yaw: 0.6, pitch: 1.05),
        scale: const ViewScale(),
        belt: belt,
      );

      await shoot(
        'belt_edge',
        meshes,
        camera: OrbitCamera(distance: 80, yaw: 0.3, pitch: 0.05),
        scale: const ViewScale(),
        belt: belt,
      );

      await shoot(
        'inner',
        meshes,
        camera: OrbitCamera(distance: 14, yaw: 0.9, pitch: 0.35),
        scale: const ViewScale(),
      );

      final vm.Vector3 earth = bodyWorldPosition(
        SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
        const ViewScale(),
        BodyCatalog.earth,
      );

      final vm.Vector3 moon = bodyWorldPosition(
        SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
        const ViewScale(),
        BodyCatalog.moon,
      );

      await shoot(
        'moon',
        meshes,
        camera: OrbitCamera(target: moon, distance: 0.9, yaw: 0.4, pitch: 0.15),
        scale: const ViewScale(),
        showOrbits: false,
      );

      await shoot(
        'earth',
        meshes,
        camera: OrbitCamera(target: earth, distance: 2.4, yaw: 0.5, pitch: 0.25),
        scale: const ViewScale(),
      );
    });
  });
}
