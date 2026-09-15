import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/view_scale.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/models/celestial_body.dart';
import 'package:solar_system_app/services/physics/simulation.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:solar_system_app/services/render/star_field.dart';
import 'package:solar_system_app/services/render/orbit_camera.dart';
import 'package:solar_system_app/services/render/solar_system_painter.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

final DateTime _instant = DateTime.utc(2026, 9, 9);
const ui.Size _size = ui.Size(600, 600);

/// Brightest channel of the colour the scene clears to.
const int _emptySpace = 10;

Future<Uint8List> render(
  Map<String, MeshAsset> meshes,
  CelestialBody body, {
  required double distance,
}) async {
  final vm.Vector3 at = bodyWorldPosition(
    SolarSystemSimulation(start: _instant),
    const ViewScale(),
    body,
  );
  // A quarter turn round from the Sun, so the body shows half lit.
  final double sunward = math.atan2(at.x, at.z);

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  SolarSystemPainter(
    simulation: SolarSystemSimulation(start: _instant),
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
    showMoons: false,
    belt: null,
    showBelt: false,
    repaint: ValueNotifier<int>(0),
  ).paint(ui.Canvas(recorder), _size);

  final ui.Image image = await recorder.endRecording().toImage(600, 600);
  return (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
}

/// Mean brightness over an annulus between [from] and [to] times [radius].
double ringBrightness(Uint8List pixels, double radius, double from, double to) {
  double total = 0;
  int counted = 0;
  for (int y = 0; y < 600; y++) {
    for (int x = 0; x < 600; x++) {
      final double r = math.sqrt(
        math.pow(x - 300.0, 2) + math.pow(y - 300.0, 2),
      );
      if (r < radius * from || r > radius * to) {
        continue;
      }
      final int i = (y * 600 + x) * 4;
      // Net of the empty-space colour the scene is cleared to, so this counts
      // light the bodies put there rather than the backdrop.
      total += math.max(
        0,
        math.max(pixels[i], math.max(pixels[i + 1], pixels[i + 2])) -
            _emptySpace,
      );
      counted++;
    }
  }
  return counted == 0 ? 0 : total / counted;
}

/// How brightly a body's rim glows, measured against the body itself.
///
/// Taken as a ratio rather than an absolute, because Earth's face is mostly
/// dark ocean while Mercury's is bright rock: comparing the two raw would say
/// more about their albedo than about whether either has any air.
double rimRatio(Uint8List pixels, double radius) {
  final double disc = ringBrightness(pixels, radius, 0.0, 0.75);
  // Clear of the limb itself: displacement and antialiasing carry the disc a
  // few percent past its nominal radius.
  final double rim = ringBrightness(pixels, radius, 1.08, 1.20);
  return disc <= 1.0 ? 0.0 : rim / disc;
}

void main() {
  testWidgets('a body with air has a rim and an airless one does not', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
      for (final CelestialBody body in BodyCatalog.all) {
        meshes[body.key] = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );
      }

      double rimFor(Uint8List pixels, CelestialBody body, double distance) {
        final OrbitCamera camera = OrbitCamera(distance: distance);
        final double focal = camera.focalLength(_size.width, _size.height);
        return rimRatio(
          pixels,
          focal * const ViewScale().bodyRadius(body.radiusKm) / distance,
        );
      }

      const double distance = 2.6;
      final double earth = rimFor(
        await render(meshes, BodyCatalog.earth, distance: distance),
        BodyCatalog.earth,
        distance,
      );
      final double mercury = rimFor(
        await render(meshes, BodyCatalog.mercury, distance: 1.2),
        BodyCatalog.mercury,
        1.2,
      );

      expect(
        earth,
        greaterThan(0.15),
        reason: 'Earth should carry a lit rim of air past its edge',
      );
      expect(
        mercury,
        lessThan(0.03),
        reason: 'Mercury has none, so nothing should glow past its edge',
      );
    });
  });

  testWidgets('a distant body is still drawn, and still shows its phase', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
      for (final CelestialBody body in BodyCatalog.all) {
        meshes[body.key] = await GlbReader.parse(
          await File(body.modelAsset).readAsBytes(),
        );
      }

      // Far enough out that Venus falls below the size at which it is worth
      // triangles and becomes a flat disc instead.
      final Uint8List pixels = await render(
        meshes,
        BodyCatalog.venus,
        distance: 40.0,
      );

      int lit = 0;
      int dark = 0;
      for (int y = 290; y < 310; y++) {
        for (int x = 280; x < 320; x++) {
          final int i = (y * 600 + x) * 4;
          final int level = math.max(
            pixels[i],
            math.max(pixels[i + 1], pixels[i + 2]),
          );
          if (level > 90) {
            lit++;
          } else if (level > 2) {
            dark++;
          }
        }
      }

      expect(lit, greaterThan(0), reason: 'the lit half should be there');
      expect(dark, greaterThan(0), reason: 'and the unlit half too');
    });
  });
}
