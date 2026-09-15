import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
    final List<CelestialBody> bodies = BodyCatalog.all;

    // Ring systems are separate meshes, loaded alongside their planet.
    final List<String> assets = <String>[
      for (final CelestialBody body in bodies) body.modelAsset,
      for (final CelestialBody body in bodies)
        if (body.ringModelAsset != null) body.ringModelAsset!,
    ];
    final List<String> labels = <String>[
      for (final CelestialBody body in bodies) body.label,
      for (final CelestialBody body in bodies)
        if (body.ringModelAsset != null) '${body.label} rings',
    ];

    for (int i = 0; i < assets.length; i++) {
      status.value = labels[i];
      final String key = assets[i].split('/').last.replaceAll('.glb', '');
      try {
        final ByteData data = await rootBundle.load(assets[i]);
        meshes[key] = await GlbReader.parse(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
      } catch (error) {
        errors.add('${labels[i]}: $error');
      }
      progress.value = (i + 1) / assets.length;
    }

    status.value = 'Ready';
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
