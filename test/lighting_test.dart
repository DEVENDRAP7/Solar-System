import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/render/body_renderer.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:vector_math/vector_math_64.dart';

/// A unit sphere with plain white skin, so whatever comes out of the renderer
/// is the lighting and nothing else.
MeshAsset whiteSphere(ui.Image skin, {int rings = 48, int segments = 96}) {
  final List<double> positions = <double>[];
  final List<double> uvs = <double>[];
  final List<int> indices = <int>[];

  for (int ring = 0; ring <= rings; ring++) {
    final double v = ring / rings;
    final double phi = v * math.pi;
    for (int segment = 0; segment <= segments; segment++) {
      final double u = segment / segments;
      final double theta = u * 2 * math.pi;
      positions.addAll(<double>[
        math.sin(phi) * math.cos(theta),
        math.cos(phi),
        math.sin(phi) * math.sin(theta),
      ]);
      uvs.addAll(<double>[u, 1.0 - v]);
    }
  }
  for (int ring = 0; ring < rings; ring++) {
    for (int segment = 0; segment < segments; segment++) {
      final int a = ring * (segments + 1) + segment;
      final int b = a + segments + 1;
      // Wound the same way the exported models are — counter-clockwise seen
      // from outside — so this exercises the renderer's face culling rather
      // than sneaking past it.
      indices.addAll(<int>[a, a + 1, b, a + 1, b + 1, b]);
    }
  }

  final Float32List points = Float32List.fromList(positions);
  return MeshAsset(
    positions: points,
    // On a unit sphere the normal at a point is the point.
    normals: Float32List.fromList(positions),
    uvs: Float32List.fromList(uvs),
    indices: Uint16List.fromList(indices),
    texture: skin,
  );
}

Future<ui.Image> white() {
  final Completer<ui.Image> done = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(<int>[255, 255, 255, 255]),
    1,
    1,
    ui.PixelFormat.rgba8888,
    done.complete,
  );
  return done.future;
}

/// Average brightness of the sphere, rendered lit from [lightDirection].
Future<double> brightness(
  MeshAsset sphere, {
  required Vector3 lightDirection,
  double? ambient,
  double? fill,
}) async {
  const ui.Size size = ui.Size(200, 200);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  final OrbitCamera camera = OrbitCamera(distance: 6, yaw: 0, pitch: 0);

  BodyRenderer.draw(
    canvas,
    sphere,
    model: Matrix4.identity(),
    view: camera.view,
    size: size,
    focalLength: camera.focalLength(size.width, size.height),
    lightDirection: lightDirection,
    viewDirection: (camera.eye).normalized(),
    ambient: ambient ?? 0.20,
    fill: fill ?? 0.07,
  );

  final ui.Image image = await recorder.endRecording().toImage(200, 200);
  final ByteData pixels = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;

  // Only the middle of the disc, well clear of the limb.
  double total = 0;
  int counted = 0;
  for (int y = 85; y < 115; y++) {
    for (int x = 85; x < 115; x++) {
      total += pixels.getUint8((y * 200 + x) * 4);
      counted++;
    }
  }
  return total / counted / 255.0;
}

Vector3 _vertex(MeshAsset mesh, int index) => Vector3(
  mesh.positions[index * 3],
  mesh.positions[index * 3 + 1],
  mesh.positions[index * 3 + 2],
);

void main() {
  testWidgets('the side facing the Sun is lit and the far side is not', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final MeshAsset sphere = whiteSphere(await white());

      // The camera sits on +z looking back at the origin.
      final double day = await brightness(
        sphere,
        lightDirection: Vector3(0, 0, 1),
      );
      final double night = await brightness(
        sphere,
        lightDirection: Vector3(0, 0, -1),
      );
      final double edge = await brightness(
        sphere,
        lightDirection: Vector3(1, 0, 0),
      );

      // If the renderer ever culls the wrong faces it draws the far side of
      // the globe from the inside, and these two swap over.
      expect(day, greaterThan(0.9), reason: 'full sun should be full bright');
      expect(night, lessThan(0.3), reason: 'the far side must go dark');
      expect(day / night, greaterThan(3.0), reason: 'a real day/night');
      // Side-on, the middle of the disc is right on the terminator.
      expect(edge, closeTo((day + night) / 2, 0.12));
    });
  });

  testWidgets('every exported mesh is wound the way the renderer expects', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      // The renderer decides which face of a triangle it is looking at from
      // the winding it ends up with on screen. If the models were ever
      // exported wound the other way it would keep the back faces instead and
      // draw each globe from the inside — which looks almost right, but mirrors
      // the map and lights the wrong half of the body.
      for (final CelestialBody body in BodyCatalog.planetsAndSun) {
        final MeshAsset mesh = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );

        int outward = 0;
        for (int t = 0; t < mesh.indices.length; t += 3) {
          final Vector3 a = _vertex(mesh, mesh.indices[t]);
          final Vector3 b = _vertex(mesh, mesh.indices[t + 1]);
          final Vector3 c = _vertex(mesh, mesh.indices[t + 2]);
          // On a body centred at the origin, the centroid points outward.
          final Vector3 face = (b - a).cross(c - a);
          if (face.dot(a + b + c) > 0) {
            outward++;
          }
        }

        expect(
          outward,
          mesh.triangleCount,
          reason: '${body.key} should be wound anticlockwise seen from outside',
        );
      }
    });
  });

  testWidgets('the terminator is a gradient, not a step', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final MeshAsset sphere = whiteSphere(await white());

      // Walk the light around and check brightness climbs smoothly.
      final List<double> walk = <double>[];
      for (int step = 0; step <= 8; step++) {
        final double angle = math.pi * step / 8;
        walk.add(
          await brightness(
            sphere,
            lightDirection: Vector3(math.sin(angle), 0, -math.cos(angle)),
          ),
        );
      }

      for (int i = 1; i < walk.length; i++) {
        expect(walk[i], greaterThanOrEqualTo(walk[i - 1] - 1e-6));
      }
      expect(walk.first, lessThan(0.3));
      expect(walk.last, greaterThan(0.9));
    });
  });
}
