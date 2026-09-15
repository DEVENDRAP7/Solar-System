import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/asteroid_belt.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/models/surface_feature.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/body_inspector.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:solar_system_app/services/render/star_field.dart';
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
  Map<String, List<SurfaceFeature>> features =
      const <String, List<SurfaceFeature>>{},
  ui.Size size = const ui.Size(720, 1280),
  DateTime? at,
  bool showOrbits = true,
  BodyInspector? inspector,
}) async {
  final SolarSystemSimulation simulation = SolarSystemSimulation(
    start: at ?? DateTime.utc(2026, 9, 9),
  );

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  SolarSystemPainter(
    simulation: simulation,
    camera: camera,
    meshes: meshes,
    scale: scale,
    stars: StarField.banded(StarField.make(2600)),
    hits: <BodyHit>[],
    showOrbits: showOrbits,
    showMoons: true,
    belt: belt,
    inspector: inspector,
    features: features,
    repaint: ValueNotifier<int>(0),
  ).paint(canvas, size);

  final ui.Image image = await recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
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
        meshes[body.key] = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );

        // Ring systems are separate meshes, keyed by their file name.
        final String? ring = body.ringModelAsset;
        if (ring != null) {
          meshes[ring.split('/').last.replaceAll('.glb', '')] =
              await GlbReader.parse(await File(ring).readAsBytes());
        }
      }
      for (final String rings in <String>[
        'saturn_rings',
        'uranus_rings',
        'neptune_rings',
      ]) {
        expect(meshes.containsKey(rings), isTrue, reason: rings);
      }
      expect(
        meshes.length,
        BodyCatalog.all.length + 3,
        reason: 'bodies plus three ring systems',
      );

      final Map<String, List<SurfaceFeature>> named =
          <String, List<SurfaceFeature>>{};
      for (final SurfaceFeature feature in SurfaceFeature.parse(
        File('assets/data/features.csv').readAsStringSync(),
      )) {
        named
            .putIfAbsent(feature.bodyKey, () => <SurfaceFeature>[])
            .add(feature);
      }
      for (final List<SurfaceFeature> list in named.values) {
        list.sort(
          (SurfaceFeature a, SurfaceFeature b) =>
              b.diameterKm.compareTo(a.diameterKm),
        );
      }
      expect(named['moon'], isNotEmpty);

      final AsteroidBelt belt = AsteroidBelt.parse(
        File('assets/data/asteroids.csv').readAsStringSync(),
      );
      expect(belt.count, greaterThan(1000));

      // Exactly the view the app opens on.
      await shoot(
        'opening',
        meshes,
        camera: OrbitCamera.overview(),
        scale: const ViewScale(),
        belt: belt,
      );

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

      final vm.Vector3 jupiter = bodyWorldPosition(
        SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
        const ViewScale(),
        BodyCatalog.jupiter,
      );

      await shoot(
        'jupiter_moons',
        meshes,
        camera: OrbitCamera(
          target: jupiter,
          distance: 7.5,
          yaw: 0.5,
          pitch: 0.25,
        ),
        scale: const ViewScale(),
        showOrbits: false,
      );

      final vm.Vector3 saturn = bodyWorldPosition(
        SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
        const ViewScale(),
        BodyCatalog.saturn,
      );

      await shoot(
        'saturn_moons',
        meshes,
        camera: OrbitCamera(
          target: saturn,
          distance: 6.5,
          yaw: 1.1,
          pitch: 0.95,
        ),
        scale: const ViewScale(),
        showOrbits: false,
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
        camera: OrbitCamera(
          target: earth,
          distance: 2.4,
          yaw: 0.5,
          pitch: 0.25,
        ),
        scale: const ViewScale(),
      );

      // The rocky bodies close up, lit from the side, which is the only way
      // relief ever shows: their real topography is displaced into the mesh.
      for (final String key in <String>[
        'mercury',
        'mars',
        'venus',
        'uranus',
        'neptune',
      ]) {
        final CelestialBody body = BodyCatalog.byKey(key)!;
        final vm.Vector3 at = bodyWorldPosition(
          SolarSystemSimulation(start: DateTime.utc(2026, 9, 9)),
          const ViewScale(),
          body,
        );
        await shoot(
          '${key}_close',
          meshes,
          features: named,
          camera: OrbitCamera(
            target: at,
            distance: const ViewScale().bodyRadius(body.radiusKm) * 4.0,
            yaw: math.atan2(
              math.cos(math.atan2(at.x, at.z)),
              -math.sin(math.atan2(at.x, at.z)),
            ),
            pitch: 0.12,
          ),
          scale: const ViewScale(),
          showOrbits: false,
        );
      }

      // Day and night. The camera is placed relative to the Sun rather than
      // by eye: a quarter turn round from it puts the terminator straight down
      // the middle of the disc, and directly opposite it shows the whole night
      // side with the cities lit.
      double towardSun(vm.Vector3 body) => math.atan2(body.x, body.z);

      for (final MapEntry<String, vm.Vector3> body in <String, vm.Vector3>{
        'earth': earth,
        'moon': moon,
      }.entries) {
        final double sunward = towardSun(body.value);
        final double distance = body.key == 'earth' ? 2.4 : 0.9;

        await shoot(
          '${body.key}_terminator',
          meshes,
          features: named,
          camera: OrbitCamera(
            target: body.value,
            distance: distance,
            // A quarter turn round from the Sun: half lit, half dark.
            yaw: math.atan2(math.cos(sunward), -math.sin(sunward)),
            pitch: 0.1,
          ),
          scale: const ViewScale(),
          showOrbits: false,
        );

        await shoot(
          '${body.key}_nightside',
          meshes,
          camera: OrbitCamera(
            target: body.value,
            distance: distance,
            // Directly away from the Sun, so the whole face is in darkness.
            yaw: sunward,
            pitch: 0.1,
          ),
          scale: const ViewScale(),
          showOrbits: false,
        );
      }

      // Earth turned by hand, from one camera that never moves. Flick between
      // these four and only the planet changes: the orbit rings, the stars and
      // the Moon are pinned exactly where they were.
      for (int step = 0; step < 4; step++) {
        final BodyInspector inspector = BodyInspector()..focus('earth');
        inspector.turn(step * 1.4, step * 0.12);
        await shoot(
          'earth_turn_$step',
          meshes,
          camera: OrbitCamera(
            target: earth,
            distance: 2.4,
            yaw: 0.5,
            pitch: 0.25,
          ),
          scale: const ViewScale(),
          inspector: inspector,
        );
      }
    });
  });
}
