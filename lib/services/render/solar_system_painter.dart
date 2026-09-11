import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../config/view_scale.dart';
import '../../models/asteroid_belt.dart';
import '../../models/body_catalog.dart';
import '../../models/celestial_body.dart';
import '../physics/kepler.dart';
import '../physics/simulation.dart';
import 'body_inspector.dart';
import 'body_renderer.dart';
import 'mesh_asset.dart';
import 'orbit_camera.dart';

/// Scene position of [body], in scene units with y up.
///
/// Shared by the painter and the camera so a body is only ever placed one way.
Vector3 bodyWorldPosition(
  SolarSystemSimulation simulation,
  ViewScale scale,
  CelestialBody body,
) {
  Vector3 scaled(Vector3 astronomical) {
    final double length = astronomical.length;
    if (length <= 0) {
      return Vector3.zero();
    }
    return astronomical * (scale.distance(length) / length);
  }

  // Ecliptic coordinates are z-up; the scene is y-up.
  Vector3 toScene(Vector3 ecliptic) =>
      Vector3(ecliptic.x, ecliptic.z, -ecliptic.y);

  if (body.elements == null) {
    return Vector3.zero();
  }
  if (body.parentKey == null) {
    return toScene(scaled(simulation.heliocentricPosition(body)));
  }

  final CelestialBody? parent = BodyCatalog.byKey(body.parentKey!);
  if (parent == null) {
    return Vector3.zero();
  }

  final Vector3 parentPosition = bodyWorldPosition(simulation, scale, parent);
  final Vector3 relative = simulation.relativePosition(body);
  final double length = relative.length;
  if (length <= 0) {
    return parentPosition;
  }

  final double drawn = scale.satelliteDistance(
    astronomicalUnits: length,
    semiMajorAxisAu: body.elements!.semiMajorAxisAu,
    parentRadiusKm: parent.radiusKm,
    parentRadiusUnits: scale.bodyRadius(parent.radiusKm),
    moonRadiusUnits: scale.bodyRadius(body.radiusKm, isMoon: true),
  );

  return parentPosition + toScene(relative * (drawn / length));
}

/// Where a body ended up on screen, so taps can be matched to it.
class BodyHit {
  const BodyHit(this.key, this.center, this.radius);

  final String key;
  final Offset center;
  final double radius;
}

/// Draws the whole scene: stars, orbit paths and the bodies themselves.
class SolarSystemPainter extends CustomPainter {
  SolarSystemPainter({
    required this.simulation,
    required this.camera,
    required this.meshes,
    required this.scale,
    required this.stars,
    required this.hits,
    required this.showOrbits,
    required this.showMoons,
    required this.repaint,
    this.belt,
    this.showBelt = true,
    this.inspector,
  }) : super(repaint: repaint);

  final SolarSystemSimulation simulation;
  final OrbitCamera camera;
  final Map<String, MeshAsset> meshes;
  final ViewScale scale;
  final List<Vector3> stars;
  final bool showOrbits;
  final bool showMoons;
  final Listenable repaint;

  /// The main-belt asteroids, once loaded.
  final AsteroidBelt? belt;
  final bool showBelt;

  /// Filled in on every paint so hit testing matches what is on screen.
  final List<BodyHit> hits;

  /// The turn the user has put on the body they are inspecting, if any.
  final BodyInspector? inspector;

  static const double _starShell = 1600.0;

  /// Below this many pixels across, a body is drawn as a point of light.
  static const double _pointThreshold = 2.6;

  /// Ecliptic coordinates are z-up; the scene is y-up.
  static Vector3 _toScene(Vector3 ecliptic) =>
      Vector3(ecliptic.x, ecliptic.z, -ecliptic.y);

  Vector3 _scaled(Vector3 astronomical) {
    final double length = astronomical.length;
    if (length <= 0) {
      return Vector3.zero();
    }
    return astronomical * (scale.distance(length) / length);
  }

  /// Project a world point; returns null when it is behind the camera.
  Offset? _project(Vector3 world, Matrix4 view, ui.Size size, double focal) {
    final Vector3 v = view.transformed3(world);
    if (v.z >= -1e-4) {
      return null;
    }
    return Offset(
      size.width / 2 + focal * v.x / -v.z,
      size.height / 2 - focal * v.y / -v.z,
    );
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    hits.clear();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF05060A),
    );

    final Matrix4 view = camera.view;
    final double focal = camera.focalLength(size.width, size.height);

    _paintStars(canvas, size, view, focal);
    if (showOrbits) {
      _paintOrbits(canvas, size, view, focal);
    }
    if (showBelt) {
      _paintBelt(canvas, size, view, focal);
    }
    _paintBodies(canvas, size, view, focal);
  }

  void _paintStars(ui.Canvas canvas, ui.Size size, Matrix4 view, double focal) {
    // Stars sit on a distant shell centred on the camera, so they never move
    // with position, only with heading.
    final Vector3 eye = camera.eye;
    final Paint paint = Paint()..color = const Color(0xCCE8EEFF);
    final List<Offset> points = <Offset>[];

    for (final Vector3 direction in stars) {
      final Offset? point = _project(
        eye + direction * _starShell,
        view,
        size,
        focal,
      );
      if (point != null) {
        points.add(point);
      }
    }
    if (points.isNotEmpty) {
      canvas.drawPoints(ui.PointMode.points, points, paint..strokeWidth = 1.6);
    }
  }

  /// Draw the asteroids as points.
  ///
  /// They are drawn before the planets so a planet in front of the belt hides
  /// the asteroids behind it, and each one is faded by distance so the belt
  /// reads as a band with depth rather than a flat scatter.
  void _paintBelt(ui.Canvas canvas, ui.Size size, Matrix4 view, double focal) {
    final AsteroidBelt? belt = this.belt;
    if (belt == null) {
      return;
    }

    belt.updatePositions(simulation.daysSinceJ2000);

    final List<Offset> near = <Offset>[];
    final List<Offset> far = <Offset>[];
    final Vector3 point = Vector3.zero();

    for (int index = 0; index < belt.count; index++) {
      point.setValues(
        belt.positions[index * 3],
        belt.positions[index * 3 + 1],
        belt.positions[index * 3 + 2],
      );

      final double length = point.length;
      if (length <= 0) {
        continue;
      }
      point.scale(scale.distance(length) / length);

      final Vector3 world = _toScene(point);
      final Vector3 viewSpace = view.transformed3(world);
      if (viewSpace.z >= -1e-4) {
        continue;
      }

      final double depth = -viewSpace.z;
      final Offset screen = Offset(
        size.width / 2 + focal * viewSpace.x / depth,
        size.height / 2 - focal * viewSpace.y / depth,
      );

      if (screen.dx < -8 ||
          screen.dy < -8 ||
          screen.dx > size.width + 8 ||
          screen.dy > size.height + 8) {
        continue;
      }

      // Two passes rather than a colour per point: far ones dim, near ones
      // brighter, which is enough to give the band its depth.
      (depth < camera.distance ? near : far).add(screen);
    }

    if (far.isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        far,
        Paint()
          ..color = const Color(0x777D8AA0)
          ..strokeWidth = 1.3,
      );
    }
    if (near.isNotEmpty) {
      canvas.drawPoints(
        ui.PointMode.points,
        near,
        Paint()
          ..color = const Color(0xCCB9C4D8)
          ..strokeWidth = 1.8,
      );
    }
  }

  void _paintOrbits(
    ui.Canvas canvas,
    ui.Size size,
    Matrix4 view,
    double focal,
  ) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0x664F8FD8);

    for (final CelestialBody body in BodyCatalog.all) {
      final orbit = body.elements;
      if (orbit == null || body.parentKey != null) {
        continue;
      }

      final List<Vector3> path = Kepler.orbitPath(
        orbit,
        simulation.centuries,
        segments: 160,
      );
      final Path line = Path();
      bool started = false;

      for (final Vector3 point in path) {
        final Offset? screen = _project(
          _toScene(_scaled(point)),
          view,
          size,
          focal,
        );
        if (screen == null) {
          started = false;
          continue;
        }
        if (started) {
          line.lineTo(screen.dx, screen.dy);
        } else {
          line.moveTo(screen.dx, screen.dy);
          started = true;
        }
      }
      canvas.drawPath(line, paint);
    }
  }

  void _paintBodies(
    ui.Canvas canvas,
    ui.Size size,
    Matrix4 view,
    double focal,
  ) {
    final List<_Placed> placed = <_Placed>[];
    final Vector3 cameraRight = camera.right;
    final BodyInspector? inspector = this.inspector;

    for (final CelestialBody body in BodyCatalog.all) {
      if (body.parentKey != null && !showMoons) {
        continue;
      }
      final MeshAsset? mesh = meshes[body.key];
      if (mesh == null) {
        continue;
      }

      final Vector3 world = _worldPosition(body);
      final Vector3 viewSpace = view.transformed3(world);
      placed.add(_Placed(body, mesh, world, viewSpace.z));
    }

    // Painter's algorithm between bodies: furthest first.
    placed.sort((_Placed a, _Placed b) => a.depth.compareTo(b.depth));

    for (final _Placed item in placed) {
      final bool isMoon = item.body.parentKey != null;
      final double radius = scale.bodyRadius(
        item.body.radiusKm,
        isMoon: isMoon,
      );

      // Moons are not drawn as points: the outer systems hold twenty of them
      // and they would crowd around their planet as a smear of dots.
      if (isMoon) {
        final double depth = -item.depth;
        if (depth <= 0 || focal * radius / depth < _pointThreshold) {
          continue;
        }
      }
      final Vector3 toSun = item.world.length < 1e-6
          ? Vector3(0, 0, 1)
          : (-item.world.normalized());

      // A body the user is turning by hand gets that turn on top of its own
      // rotation. Only this body moves: the camera stays exactly where it is,
      // so everything behind it holds still.
      final Matrix4 tip = inspector == null
          ? Matrix4.identity()
          : inspector.tipFor(item.body.key, cameraRight);
      final double handSpin = inspector?.spinFor(item.body.key) ?? 0.0;

      final Matrix4 model = Matrix4.identity()
        ..setTranslation(item.world)
        ..multiply(tip)
        ..rotateZ(item.body.axialTiltDeg * math.pi / 180.0)
        ..rotateY(simulation.spinRadians(item.body) + handSpin)
        ..scaleByDouble(radius, radius, radius, 1.0);

      // Too small to be worth triangles: draw it as a point of light instead,
      // in its own colour, so a planet is always visible however far out you
      // are. Without this the inner planets simply vanish at system scale.
      final double bodyDepth = -item.depth;
      final double screenSize = bodyDepth > 0 ? focal * radius / bodyDepth : 0;

      if (screenSize < _pointThreshold) {
        final Offset? spot = _project(item.world, view, size, focal);
        if (spot != null) {
          final double glow = math.max(screenSize, 1.4);
          canvas.drawCircle(
            spot,
            glow * 2.6,
            Paint()
              ..color = item.mesh.averageColour.withValues(alpha: 0.22)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow * 1.4),
          );
          canvas.drawCircle(
            spot,
            glow,
            Paint()..color = item.mesh.averageColour,
          );
          hits.add(BodyHit(item.body.key, spot, math.max(glow * 4, 18.0)));
        }
        continue;
      }

      final Vector3 toEye = (camera.eye - item.world);
      if (toEye.length > 1e-6) {
        toEye.normalize();
      }

      // A ring lies in its planet's equator, sharing the tilt but not the
      // spin. It is drawn in two passes around the planet so the far side
      // passes behind it.
      final MeshAsset? rings = item.body.ringModelAsset == null
          ? null
          : meshes[item.body.ringModelAsset!
                .split('/')
                .last
                .replaceAll('.glb', '')];

      final Matrix4 ringModel = Matrix4.identity()
        ..setTranslation(item.world)
        ..multiply(tip)
        ..rotateZ(item.body.axialTiltDeg * math.pi / 180.0)
        ..scaleByDouble(radius, radius, radius, 1.0);

      if (rings != null) {
        BodyRenderer.draw(
          canvas,
          rings,
          model: ringModel,
          view: view,
          size: size,
          focalLength: focal,
          lightDirection: toSun,
          viewDirection: toEye,
          cull: false,
          twoSided: true,
          fartherThan: item.depth,
        );
      }

      BodyRenderer.draw(
        canvas,
        item.mesh,
        model: model,
        view: view,
        size: size,
        focalLength: focal,
        lightDirection: toSun,
        viewDirection: toEye,
        emissive: item.body.isStar,
      );

      if (rings != null) {
        BodyRenderer.draw(
          canvas,
          rings,
          model: ringModel,
          view: view,
          size: size,
          focalLength: focal,
          lightDirection: toSun,
          viewDirection: toEye,
          cull: false,
          twoSided: true,
          nearerThan: item.depth,
        );
      }

      final Offset? centre = _project(item.world, view, size, focal);
      if (centre != null) {
        final double depth = -item.depth;
        final double screenRadius = depth > 0 ? focal * radius / depth : 0.0;
        hits.add(BodyHit(item.body.key, centre, math.max(screenRadius, 16.0)));
      }
    }
  }

  Vector3 _worldPosition(CelestialBody body) =>
      bodyWorldPosition(simulation, scale, body);

  @override
  bool shouldRepaint(covariant SolarSystemPainter oldDelegate) => true;
}

class _Placed {
  const _Placed(this.body, this.mesh, this.world, this.depth);

  final CelestialBody body;
  final MeshAsset mesh;
  final Vector3 world;
  final double depth;
}
