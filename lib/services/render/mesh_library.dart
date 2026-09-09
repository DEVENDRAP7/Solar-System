import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../models/body_catalog.dart';
import '../../models/celestial_body.dart';
import 'mesh_asset.dart';

/// Loads the body models and keeps them for the painter.
class MeshLibrary {
  MeshLibrary();

  final Map<String, MeshAsset> meshes = <String, MeshAsset>{};
  final List<String> errors = <String>[];

  /// Progress from 0 to 1 while loading.
  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);

  /// What is loading now, for the loading screen.
  final ValueNotifier<String> status = ValueNotifier<String>('Loading');

  bool get isEmpty => meshes.isEmpty;

  /// Load every body, reporting progress as it goes.
  ///
  /// Each model is a small glTF binary whose texture the engine decodes
  /// natively, so the whole set takes well under a second.
  Future<void> loadAll() async {
    const List<CelestialBody> bodies = BodyCatalog.all;

    for (int i = 0; i < bodies.length; i++) {
      final CelestialBody body = bodies[i];
      status.value = body.label;
      try {
        final ByteData data = await rootBundle.load(body.modelAsset);
        meshes[body.key] = await GlbReader.parse(data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ));
      } catch (error) {
        errors.add('${body.label}: $error');
      }
      progress.value = (i + 1) / bodies.length;
    }

    status.value = 'Ready';
  }

  /// Random directions used for the star field.
  static List<Vector3> makeStars(int count, {int seed = 20260908}) {
    final math.Random random = math.Random(seed);
    return List<Vector3>.generate(count, (int _) {
      final double u = random.nextDouble() * 2.0 - 1.0;
      final double theta = random.nextDouble() * 2.0 * math.pi;
      final double r = math.sqrt(1.0 - u * u);
      return Vector3(r * math.cos(theta), u, r * math.sin(theta));
    });
  }

  void dispose() {
    progress.dispose();
    status.dispose();
    for (final MeshAsset mesh in meshes.values) {
      mesh.texture?.dispose();
    }
    meshes.clear();
  }
}
