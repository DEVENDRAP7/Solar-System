import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:vector_math/vector_math_64.dart' as vm;

import '../../config/view_scale.dart';
import '../../models/body_catalog.dart';
import '../../models/celestial_body.dart';
import '../physics/kepler.dart';
import '../physics/simulation.dart';

/// The scene graph nodes belonging to one body.
///
/// Each body is three nested objects so the transforms stay independent: the
/// pivot carries its position in the scene, the tilt node holds the axial tilt,
/// and the spin node turns the model about its own axis.
class BodyNode {
  BodyNode({
    required this.body,
    required this.pivot,
    required this.tilt,
    required this.spin,
    required this.radiusUnits,
  });

  final CelestialBody body;
  final three.Object3D pivot;
  final three.Object3D tilt;
  final three.Object3D spin;
  double radiusUnits;
}

/// Builds and drives the 3D solar system.
class SolarSystemScene {
  SolarSystemScene({required this.simulation});

  final SolarSystemSimulation simulation;

  ViewScale scale = const ViewScale();

  final Map<String, BodyNode> nodes = <String, BodyNode>{};
  final Map<String, three.Object3D> orbitLines = <String, three.Object3D>{};

  three.ThreeJS? _viewer;
  three.OrbitControls? _controls;
  final three.Raycaster _raycaster = three.Raycaster();

  /// What setup is currently doing, shown while the scene loads.
  ///
  /// The viewer keeps showing its loading widget until setup returns, so
  /// without this a failure part way through is indistinguishable from a slow
  /// load: both are a spinner that never ends.
  final ValueNotifier<String> status =
      ValueNotifier<String>('Starting renderer');

  /// Anything that went wrong during setup, reported rather than thrown.
  final List<String> errors = <String>[];

  /// Flips as soon as the viewer calls into our setup, which tells us the
  /// native renderer came up. If this stays false, the failure is below us.
  final ValueNotifier<bool> setupStarted = ValueNotifier<bool>(false);

  /// True while bodies are still streaming in after the first frame.
  final ValueNotifier<bool> loadingBodies = ValueNotifier<bool>(true);

  three.GLTFLoader? _loader;

  /// How long a single model is allowed to take before it is given up on.
  static const Duration _loadTimeout = Duration(seconds: 25);

  bool showOrbits = true;
  bool showMoons = true;

  /// Where the camera is easing toward, if a body has been focused.
  vm.Vector3? _cameraTarget;
  vm.Vector3? _lookTarget;

  static const double _degToRad = math.pi / 180.0;

  /// Convert an ecliptic vector (z toward ecliptic north) into scene axes,
  /// which are y-up as glTF and three.js expect.
  static three.Vector3 _toScene(vm.Vector3 ecliptic) =>
      three.Vector3(ecliptic.x, ecliptic.z, -ecliptic.y);

  /// Build the scene into [viewer]. Call from the viewer's setup callback.
  ///
  /// Every step is guarded: a body that fails to load is reported and skipped
  /// rather than taking the whole scene down with it.
  Future<void> setup(three.ThreeJS viewer) async {
    _viewer = viewer;
    setupStarted.value = true;
    status.value = 'Preparing scene';

    viewer.camera = three.PerspectiveCamera(
      50,
      viewer.width / viewer.height,
      0.05,
      20000,
    );
    viewer.camera.position.setValues(0, 14, 34);

    viewer.scene = three.Scene();

    // Space is dark, but a little ambient light keeps night sides from going
    // completely black on a phone screen.
    viewer.scene.add(three.AmbientLight(0x2a3346, 0.55));

    // The Sun lights everything. Decay is switched off because the scene's
    // distances are compressed, so physical falloff would leave the outer
    // planets unlit.
    final three.PointLight sunLight =
        three.PointLight(0xfff2dd, 2.6, 0.0, 0.0);
    viewer.scene.add(sunLight);

    _controls = three.OrbitControls(viewer.camera, viewer.globalKey)
      ..enableDamping = true
      ..dampingFactor = 0.08
      ..minDistance = 0.6
      ..maxDistance = 900.0;

    try {
      await _addStarfield(viewer);
    } catch (error) {
      errors.add('Starfield: $error');
    }

    status.value = 'Drawing orbits';
    try {
      _buildOrbitLines(viewer);
    } catch (error) {
      errors.add('Orbits: $error');
    }

    _loader = three.GLTFLoader(flipY: false).setPath('assets/models/');

    // Only the Sun is loaded before the scene is shown. Every texture costs a
    // pure-Dart image decode on the device, so waiting for all eleven bodies
    // would hold the app on its loading screen for minutes. The rest stream in
    // afterwards against a scene that is already live.
    status.value = 'Loading the Sun';
    try {
      await _addBody(viewer, _loader!, BodyCatalog.sun);
    } catch (error) {
      errors.add('Sun: $error');
    }

    updatePositions();
    status.value = 'Ready';
  }

  /// Load everything except the Sun, one body at a time.
  ///
  /// Call this after [setup] returns, without awaiting it: each body appears
  /// as it arrives while the scene is already being rendered and driven.
  Future<void> loadRemainingBodies() async {
    final three.ThreeJS? viewer = _viewer;
    final three.GLTFLoader? loader = _loader;
    if (viewer == null || loader == null) {
      loadingBodies.value = false;
      return;
    }

    final List<CelestialBody> remaining = BodyCatalog.all
        .where((CelestialBody body) => !body.isStar)
        .toList();

    for (int index = 0; index < remaining.length; index++) {
      final CelestialBody body = remaining[index];
      status.value = '${body.label} (${index + 1} of ${remaining.length})';
      try {
        await _addBody(viewer, loader, body);
        updatePositions();
      } catch (error) {
        errors.add('${body.label}: $error');
      }
    }

    status.value = errors.isEmpty ? 'Ready' : '${errors.length} problems';
    loadingBodies.value = false;
  }

  Future<void> _addBody(
    three.ThreeJS viewer,
    three.GLTFLoader loader,
    CelestialBody body,
  ) async {
    final three.GLTFData? asset = await loader
        .fromAsset('${body.key}.glb')
        .timeout(_loadTimeout);
    if (asset == null) {
      errors.add('${body.label}: model returned no data');
      return;
    }

    final three.Object3D model = asset.scene;
    final double radiusUnits = scale.bodyRadius(body.radiusKm);

    final three.Object3D spin = three.Group()..add(model);
    final three.Object3D tilt = three.Group()..add(spin);
    final three.Object3D pivot = three.Group()..add(tilt);

    tilt.rotation.z = body.axialTiltDeg * _degToRad;
    model.scale.setValues(radiusUnits, radiusUnits, radiusUnits);

    // Tag the whole subtree so a raycast hit can be traced back to its body.
    pivot.name = body.key;
    pivot.userData['bodyKey'] = body.key;
    model.userData['bodyKey'] = body.key;

    if (body.ringModelAsset != null) {
      final three.GLTFData? rings =
          await loader.fromAsset('saturn_rings.glb').timeout(_loadTimeout);
      if (rings != null) {
        final three.Object3D ringModel = rings.scene;
        ringModel.scale.setValues(radiusUnits, radiusUnits, radiusUnits);
        ringModel.userData['bodyKey'] = body.key;
        // Rings share the planet's tilt but not its spin.
        tilt.add(ringModel);
      }
    }

    if (body.isStar) {
      // Keep the star readable at a glance rather than physically correct.
      model.scale.setValues(radiusUnits, radiusUnits, radiusUnits);
    }

    viewer.scene.add(pivot);
    nodes[body.key] = BodyNode(
      body: body,
      pivot: pivot,
      tilt: tilt,
      spin: spin,
      radiusUnits: radiusUnits,
    );
  }

  Future<void> _addStarfield(three.ThreeJS viewer) async {
    final math.Random random = math.Random(20260908);
    final List<three.Vector3> points = <three.Vector3>[];

    for (int index = 0; index < 1600; index++) {
      // Uniform directions on a sphere, pushed out beyond the planets.
      final double u = random.nextDouble() * 2.0 - 1.0;
      final double theta = random.nextDouble() * 2.0 * math.pi;
      final double r = math.sqrt(1.0 - u * u);
      const double shell = 1400.0;
      points.add(three.Vector3(
        shell * r * math.cos(theta),
        shell * u,
        shell * r * math.sin(theta),
      ));
    }

    final three.BufferGeometry geometry =
        three.BufferGeometry().setFromPoints(points);
    final three.PointsMaterial material = three.PointsMaterial.fromMap(
      <String, dynamic>{'color': 0xf2f5ff, 'size': 2.4, 'sizeAttenuation': false},
    );
    viewer.scene.add(three.Points(geometry, material));
  }

  void _buildOrbitLines(three.ThreeJS viewer) {
    for (final CelestialBody body in BodyCatalog.all) {
      final orbit = body.elements;
      if (orbit == null) {
        continue;
      }
      if (body.parentKey != null) {
        // Moon paths move with their planet and are cheap to leave out.
        continue;
      }

      final List<vm.Vector3> path =
          Kepler.orbitPath(orbit, simulation.centuries, segments: 240);
      final List<three.Vector3> points = path
          .map((vm.Vector3 point) => _toScene(_scaleHeliocentric(point)))
          .toList();

      final three.BufferGeometry geometry =
          three.BufferGeometry().setFromPoints(points);
      final three.LineBasicMaterial material = three.LineBasicMaterial.fromMap(
        <String, dynamic>{
          'color': 0x4f6d99,
          'transparent': true,
          'opacity': 0.45,
        },
      );

      final three.Object3D line = three.LineLoop(geometry, material);
      line.visible = showOrbits;
      viewer.scene.add(line);
      orbitLines[body.key] = line;
    }
  }

  /// Apply the distance compression to a heliocentric vector, keeping its
  /// direction so bodies stay on their drawn orbits.
  vm.Vector3 _scaleHeliocentric(vm.Vector3 astronomical) {
    final double length = astronomical.length;
    if (length <= 0) {
      return vm.Vector3.zero();
    }
    return astronomical * (scale.distance(length) / length);
  }

  /// Move every body to where the simulation says it is.
  void updatePositions() {
    for (final BodyNode node in nodes.values) {
      final CelestialBody body = node.body;

      if (body.elements == null) {
        node.pivot.position.setValues(0, 0, 0);
      } else if (body.parentKey == null) {
        final vm.Vector3 scaled =
            _scaleHeliocentric(simulation.heliocentricPosition(body));
        final three.Vector3 scenePosition = _toScene(scaled);
        node.pivot.position.setFrom(scenePosition);
      } else {
        _positionMoon(node, body);
      }

      node.spin.rotation.y = simulation.spinRadians(body);
    }
  }

  void _positionMoon(BodyNode node, CelestialBody body) {
    final BodyNode? parent = nodes[body.parentKey];
    if (parent == null) {
      return;
    }

    final vm.Vector3 relative = simulation.relativePosition(body);
    final double length = relative.length;
    if (length <= 0) {
      return;
    }

    final double drawn = scale.satelliteDistance(
      astronomicalUnits: length,
      semiMajorAxisAu: body.elements!.semiMajorAxisAu,
      parentRadiusUnits: parent.radiusUnits,
      moonRadiusUnits: node.radiusUnits,
    );

    final three.Vector3 offset = _toScene(relative * (drawn / length));
    node.pivot.position.setValues(
      parent.pivot.position.x + offset.x,
      parent.pivot.position.y + offset.y,
      parent.pivot.position.z + offset.z,
    );
    node.pivot.visible = showMoons;
  }

  /// Advance the simulation and the scene by one frame.
  void tick(double deltaSeconds) {
    simulation.advance(deltaSeconds);
    updatePositions();
    _easeCamera();
    _controls?.update();
  }

  void _easeCamera() {
    final three.ThreeJS? viewer = _viewer;
    final vm.Vector3? destination = _cameraTarget;
    final vm.Vector3? look = _lookTarget;
    if (viewer == null || destination == null || look == null) {
      return;
    }

    final three.Vector3 position = viewer.camera.position;
    const double easing = 0.08;
    position.setValues(
      position.x + (destination.x - position.x) * easing,
      position.y + (destination.y - position.y) * easing,
      position.z + (destination.z - position.z) * easing,
    );

    final three.OrbitControls? controls = _controls;
    if (controls != null) {
      controls.target.setValues(
        controls.target.x + (look.x - controls.target.x) * easing,
        controls.target.y + (look.y - controls.target.y) * easing,
        controls.target.z + (look.z - controls.target.z) * easing,
      );
    }

    if ((destination - vm.Vector3(position.x, position.y, position.z)).length <
        0.05) {
      _cameraTarget = null;
      _lookTarget = null;
    }
  }

  /// Frame [key], easing the camera to a comfortable distance from it.
  void focusOn(String key) {
    final BodyNode? node = nodes[key];
    final three.ThreeJS? viewer = _viewer;
    if (node == null || viewer == null) {
      return;
    }

    final three.Vector3 target = node.pivot.position;
    final double standOff = math.max(node.radiusUnits * 6.0, 1.2);

    _lookTarget = vm.Vector3(target.x, target.y, target.z);
    _cameraTarget = vm.Vector3(
      target.x + standOff * 0.6,
      target.y + standOff * 0.45,
      target.z + standOff,
    );
  }

  /// Pull the camera back to take in the whole system.
  void resetCamera() {
    _lookTarget = vm.Vector3.zero();
    _cameraTarget = vm.Vector3(0, 14, 34);
  }

  /// The body under [localPosition] within a viewport of [size], if any.
  String? bodyAt(Offset localPosition, Size size) {
    final three.ThreeJS? viewer = _viewer;
    if (viewer == null || size.width == 0 || size.height == 0) {
      return null;
    }

    final three.Vector2 device = three.Vector2(
      (localPosition.dx / size.width) * 2.0 - 1.0,
      -(localPosition.dy / size.height) * 2.0 + 1.0,
    );

    _raycaster.setFromCamera(device, viewer.camera);
    final List<three.Object3D> targets = nodes.values
        .where((BodyNode node) => node.pivot.visible)
        .map((BodyNode node) => node.pivot)
        .toList();

    final List<three.Intersection> hits =
        _raycaster.intersectObjects(targets, true);
    for (final three.Intersection hit in hits) {
      final String? key = _bodyKeyOf(hit.object);
      if (key != null) {
        return key;
      }
    }
    return null;
  }

  /// Walk up from a hit mesh to the body it belongs to.
  String? _bodyKeyOf(three.Object3D? object) {
    three.Object3D? current = object;
    while (current != null) {
      final dynamic key = current.userData['bodyKey'];
      if (key is String) {
        return key;
      }
      current = current.parent;
    }
    return null;
  }

  void setOrbitsVisible(bool visible) {
    showOrbits = visible;
    for (final three.Object3D line in orbitLines.values) {
      line.visible = visible;
    }
  }

  void setMoonsVisible(bool visible) {
    showMoons = visible;
    for (final BodyNode node in nodes.values) {
      if (node.body.parentKey != null) {
        node.pivot.visible = visible;
      }
    }
  }

  /// Switch between compressed and true scale, rebuilding what depends on it.
  void setScale(ViewScale next) {
    scale = next;
    final three.ThreeJS? viewer = _viewer;

    for (final BodyNode node in nodes.values) {
      final double radius = scale.bodyRadius(node.body.radiusKm);
      node.radiusUnits = radius;
      for (final three.Object3D child in node.spin.children) {
        child.scale.setValues(radius, radius, radius);
      }
      for (final three.Object3D child in node.tilt.children) {
        if (child != node.spin) {
          child.scale.setValues(radius, radius, radius);
        }
      }
    }

    if (viewer != null) {
      for (final three.Object3D line in orbitLines.values) {
        viewer.scene.remove(line);
      }
      orbitLines.clear();
      _buildOrbitLines(viewer);
    }
    updatePositions();
  }

  void dispose() {
    _controls?.dispose();
    status.dispose();
    loadingBodies.dispose();
    setupStarted.dispose();
  }
}
