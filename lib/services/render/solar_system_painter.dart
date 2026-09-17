import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../config/view_scale.dart';
import '../../models/asteroid_belt.dart';
import '../../models/body_catalog.dart';
import '../../models/celestial_body.dart';
import '../../models/surface_feature.dart';
import '../physics/kepler.dart';
import '../physics/simulation.dart';
import 'body_inspector.dart';
import 'body_renderer.dart';
import 'mesh_asset.dart';
import 'orbit_camera.dart';
import 'star_field.dart';

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
    neighbourhood: orbitalNeighbourhood(scale, parent),
    parentRingOuterRadii: parent.ringOuterRadii,
  );

  return parentPosition + toScene(relative * (drawn / length));
}

/// How far it is from [body]'s orbit to the nearest other planet's, in scene
/// units — the width of the stretch of the system that is its own.
///
/// Cached: it depends only on the scale and the catalogue, and working it out
/// for every moon of every planet on every frame is thirty times the work for
/// the same answer.
double orbitalNeighbourhood(ViewScale scale, CelestialBody body) {
  final orbit = body.elements;
  if (orbit == null || body.parentKey != null) {
    return double.infinity;
  }
  return _neighbourhoods.putIfAbsent('${scale.mode}/${body.key}', () {
    final double own = scale.distance(orbit.semiMajorAxisAu);
    double nearest = double.infinity;

    for (final CelestialBody other in BodyCatalog.planetsAndSun) {
      final otherOrbit = other.elements;
      if (otherOrbit == null || other.key == body.key) {
        continue;
      }
      final double gap = (scale.distance(otherOrbit.semiMajorAxisAu) - own)
          .abs();
      if (gap > 0 && gap < nearest) {
        nearest = gap;
      }
    }
    return nearest;
  });
}

final Map<String, double> _neighbourhoods = <String, double>{};

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
    this.features = const <String, List<SurfaceFeature>>{},
    this.showLabels = true,
  }) : super(repaint: repaint);

  final SolarSystemSimulation simulation;
  final OrbitCamera camera;
  final Map<String, MeshAsset> meshes;
  final ViewScale scale;

  /// The sky, pre-grouped so drawing it is a handful of calls.
  final List<StarBand> stars;
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

  /// The named places on each body, keyed by body.
  final Map<String, List<SurfaceFeature>> features;

  /// Whether those names are drawn.
  final bool showLabels;

  static const double _starShell = 1600.0;

  /// Below this many pixels across, a body is drawn as a point of light.
  static const double _pointThreshold = 2.6;

  /// Below this radius in pixels, a body is drawn as a shaded disc rather than
  /// as a mesh. Five thousand triangles for a dot ten pixels wide is most of a
  /// frame spent on something no one can see; at this size the disc and the
  /// mesh are the same picture, phase and all.
  static const double _meshThreshold = 11.0;

  /// A body smaller than this on screen gets no feature names: there is
  /// nowhere to put them near the thing they name.
  static const double _labelThreshold = 38.0;

  /// A moon this many pixels across is worth naming. Lower than the threshold
  /// for surface features: a name beside a moon only has to point at it,
  /// where a crater's name has to land on the right part of a disc.
  static const double _moonNameThreshold = 4.0;

  /// How far down a body's list of names to look before giving up.
  ///
  /// The Moon has nine thousand named features. Walking all of them every
  /// frame, for every body, to fill fourteen slots would cost more than the
  /// planets themselves. They are sorted largest first, so the ones worth
  /// having are near the front.
  static const int _labelSearchDepth = 600;

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
    final List<Offset> points = <Offset>[];

    for (final StarBand band in stars) {
      points.clear();
      for (final Vector3 direction in band.directions) {
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
      if (points.isEmpty) {
        continue;
      }

      // The brightest few get a soft halo, which is what makes a star read as
      // a point of light rather than a dot of paint.
      if (band.size >= 2.2) {
        canvas.drawPoints(
          ui.PointMode.points,
          points,
          Paint()
            ..color = band.colour.withValues(alpha: 0.18)
            ..strokeWidth = band.size * 3.2
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
        );
      }

      canvas.drawPoints(
        ui.PointMode.points,
        points,
        Paint()
          ..color = band.colour.withValues(
            // Faint stars are faint as well as small, or the sky reads as
            // uniform however much the sizes vary.
            alpha: (0.30 + 0.24 * band.size).clamp(0.0, 1.0),
          )
          ..strokeWidth = band.size
          ..strokeCap = StrokeCap.round,
      );
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
    final List<_Label> labels = <_Label>[];

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
      placed.add(
        _Placed(
          body,
          mesh,
          world,
          viewSpace.z,
          scale.bodyRadius(body.radiusKm, isMoon: body.parentKey != null),
        ),
      );
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

      final Vector3 toEye = (camera.eye - item.world);
      if (toEye.length > 1e-6) {
        toEye.normalize();
      }

      // How much of the face turned toward us the Sun reaches: 1 when it is
      // behind us and the body shows full, -1 when the body lies between us
      // and the Sun and shows a crescent.
      final double phase = toEye.dot(toSun).clamp(-1.0, 1.0);

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
        ..rotateX(-item.body.axialTiltDeg * math.pi / 180.0)
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

      final Offset? centre = _project(item.world, view, size, focal);
      if (centre == null) {
        continue;
      }

      // Which way the Sun lies on screen, for shading the disc and the rim.
      Offset sunOnScreen = Offset.zero;
      final Offset? sunward = _project(
        item.world + toSun * (radius * 4.0),
        view,
        size,
        focal,
      );
      if (sunward != null && (sunward - centre).distance > 1e-3) {
        sunOnScreen = (sunward - centre) / (sunward - centre).distance;
      }

      final double lit = item.body.isStar ? 1.0 : phase;

      if (screenSize < _meshThreshold) {
        _paintAtmosphere(
          canvas,
          item.body,
          centre,
          screenSize,
          lit,
          sunOnScreen,
        );
        _paintDisc(
          canvas,
          centre,
          screenSize,
          item.mesh.averageColour,
          sunOnScreen,
          lit,
        );
        hits.add(BodyHit(item.body.key, centre, math.max(screenSize, 16.0)));
        continue;
      }

      _paintAtmosphere(canvas, item.body, centre, screenSize, lit, sunOnScreen);
      if (item.body.isStar) {
        _paintCorona(canvas, centre, screenSize);
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
        ..rotateX(-item.body.axialTiltDeg * math.pi / 180.0)
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
          // A ring is a thin sheet lit through from both sides, so it has no
          // day and night of its own. It keeps the flat lighting it was
          // tuned with rather than the terminator the globes now get.
          ambient: 0.38,
          fill: 0.42,
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
        terminator: item.body.terminatorWidth,
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
          ambient: 0.38,
          fill: 0.42,
          nearerThan: item.depth,
        );
      }

      hits.add(BodyHit(item.body.key, centre, math.max(screenSize, 16.0)));

      if (showLabels) {
        _gatherFeatureLabels(
          labels,
          item,
          model,
          view,
          size,
          focal,
          screenSize,
        );
        // Moons carry their own name. A planet has one in the picker and one
        // in the details panel already; a moon has neither, so without this
        // the outer systems are a scatter of anonymous dots.
        if (item.body.parentKey != null && screenSize >= _moonNameThreshold) {
          labels.add(
            _Label(item.body.label, centre + Offset(0, -screenSize - 3), 2.0),
          );
        }
      }
    }

    if (showLabels) {
      _paintLabels(canvas, size, labels);
    }
  }

  /// Collect the named places on one body that are worth a label right now.
  ///
  /// A feature is only labelled when it is on the side of the body facing us
  /// and the body is drawn large enough for the name to land somewhere near
  /// the thing it names. They are gathered rather than drawn as we go, so no
  /// planet drawn later can cover a name.
  void _gatherFeatureLabels(
    List<_Label> into,
    _Placed item,
    Matrix4 model,
    Matrix4 view,
    ui.Size size,
    double focal,
    double screenRadius,
  ) {
    final List<SurfaceFeature>? named = features[item.body.key];
    if (named == null || named.isEmpty || screenRadius < _labelThreshold) {
      return;
    }

    // More room means more names. A body filling the screen carries a dozen;
    // one the size of a coin carries two without becoming a scribble.
    final int allowed = ((screenRadius - _labelThreshold) / 26).round().clamp(
      1,
      14,
    );

    final Vector3 toEye = (camera.eye - item.world)..normalize();
    int taken = 0;
    int considered = 0;

    for (final SurfaceFeature feature in named) {
      if (taken >= allowed || considered >= _labelSearchDepth) {
        break;
      }

      // The model matrix carries the body's tilt, its spin and any turn the
      // user has put on it, so the name goes where the surface actually is.
      final Vector3 out = model.rotated3(feature.direction)..normalize();
      final double facing = out.dot(toEye);
      if (facing < 0.22) {
        continue;
      }

      final Offset? at = _project(
        item.world + out * (item.radius * 1.01),
        view,
        size,
        focal,
      );
      if (at == null) {
        continue;
      }

      // Only what is actually on screen costs a slot. The names arrive
      // largest first, so without this a body zoomed in on spends its whole
      // budget on giants that are off the edge of the screen, and the crater
      // being looked at goes unnamed. It is also what makes zooming in reveal
      // smaller things: the giants leave the frame, and the budget passes
      // down the list.
      considered++;
      if (at.dx < -40 ||
          at.dy < -40 ||
          at.dx > size.width + 40 ||
          at.dy > size.height + 40) {
        continue;
      }

      into.add(_Label(feature.name, at, facing));
      taken++;
    }
  }

  /// Draw the gathered names, dropping any that would sit on top of another.
  void _paintLabels(ui.Canvas canvas, ui.Size size, List<_Label> labels) {
    if (labels.isEmpty) {
      return;
    }
    // Squarest-on first: when two names collide, the one nearer the middle of
    // the disc — and so the more certainly placed — is the one that survives.
    labels.sort((_Label a, _Label b) => b.facing.compareTo(a.facing));

    final List<Rect> taken = <Rect>[];

    for (final _Label label in labels) {
      final TextPainter painter = _textFor(label.text);
      final Offset at = label.at + const Offset(7, -6);
      final Rect box = Rect.fromLTWH(
        at.dx,
        at.dy,
        painter.width,
        painter.height,
      ).inflate(3);

      if (box.right > size.width || box.bottom > size.height || box.left < 0) {
        continue;
      }
      if (taken.any(box.overlaps)) {
        continue;
      }
      taken.add(box);

      canvas.drawCircle(
        label.at,
        1.7,
        Paint()..color = const Color(0xCCDCE8FF),
      );
      canvas.drawLine(
        label.at,
        at + const Offset(-2, 6),
        Paint()
          ..color = const Color(0x66DCE8FF)
          ..strokeWidth = 1,
      );
      painter.paint(canvas, at);
    }
  }

  /// Laid-out text, kept between frames: laying a string out costs more than
  /// drawing it, and these strings barely change.
  static final Map<String, TextPainter> _textCache = <String, TextPainter>{};

  static TextPainter _textFor(String text) {
    return _textCache.putIfAbsent(text, () {
      return TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            color: Color(0xF2EAF2FF),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            shadows: <Shadow>[
              Shadow(color: Color(0xE6000000), blurRadius: 3),
              Shadow(color: Color(0x99000000), blurRadius: 7),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  /// Draw a distant body as a flat disc carrying its phase.
  ///
  /// [sunOnScreen] points from the body toward the Sun in screen space, and
  /// [phase] is how much of the face turned toward us is lit: 1 is full, -1 is
  /// new. Together they put the terminator in the same place the mesh would.
  void _paintDisc(
    ui.Canvas canvas,
    Offset centre,
    double radius,
    ui.Color colour,
    Offset sunOnScreen,
    double phase,
  ) {
    final ui.Color night = ui.Color.fromARGB(
      colour.a >= 1.0 ? 255 : (colour.a * 255).round(),
      (colour.r * 255 * _nightFraction).round(),
      (colour.g * 255 * _nightFraction).round(),
      (colour.b * 255 * _nightFraction).round(),
    );

    if (sunOnScreen == Offset.zero) {
      canvas.drawCircle(centre, radius, Paint()..color = colour);
      return;
    }

    // Slide the light and dark halves apart along the Sun's direction by the
    // phase, so a body lit from behind shows a crescent and one lit from over
    // our shoulder shows a full face.
    final Offset lit = centre + sunOnScreen * radius;
    final Offset dark = centre - sunOnScreen * radius;
    final double edge = ((1.0 - phase) / 2.0).clamp(0.0, 1.0);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = ui.Gradient.linear(
          lit,
          dark,
          <ui.Color>[colour, colour, night, night],
          <double>[
            0.0,
            (edge - 0.18).clamp(0.0, 1.0),
            (edge + 0.18).clamp(0.0, 1.0),
            1.0,
          ],
        ),
    );
  }

  /// The Sun's glow.
  ///
  /// A star seen from space has no sharp edge: the photosphere is the bright
  /// disc, but the light around it falls off over several radii. Without this
  /// the Sun is a flat yellow circle pasted on the sky.
  void _paintCorona(ui.Canvas canvas, Offset centre, double radius) {
    // Kept inside Mercury's orbit. At three radii the glow swallowed the
    // inner system, washing out the one planet closest to it.
    final double reach = radius * 1.75;
    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          reach,
          const <ui.Color>[
            ui.Color(0xCCFFE9A8),
            ui.Color(0x66FFCF63),
            ui.Color(0x1AFFAE33),
            ui.Color(0x00FF9A1F),
          ],
          const <double>[0.0, 0.30, 0.58, 1.0],
        ),
    );
  }

  /// The soft rim of air around a body that has any.
  ///
  /// Drawn as a halo outside the disc, brightest where the Sun catches it. It
  /// is the cheapest thing in the scene that makes a planet read as a world
  /// rather than a textured ball.
  void _paintAtmosphere(
    ui.Canvas canvas,
    CelestialBody body,
    Offset centre,
    double radius,
    double phase,
    Offset sunOnScreen,
  ) {
    final ui.Color? air = body.atmosphere;
    if (air == null || radius < 3.0) {
      return;
    }

    final double outer = radius * (1.0 + body.atmosphereDepth * _airSpread);
    // A body lit from behind shows only a thin bright ring; one lit from in
    // front shows the whole rim. Never quite nothing: even a new moon has a
    // rim of scattered light, which is half of why it looks real.
    final double strength = (0.30 + 0.70 * ((phase + 1.0) / 2.0)) * _airOpacity;

    canvas.drawCircle(
      centre,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          outer,
          <ui.Color>[
            air.withValues(alpha: 0.0),
            air.withValues(alpha: 0.10 * strength),
            air.withValues(alpha: strength),
            air.withValues(alpha: 0.0),
          ],
          <double>[0.0, radius / outer * 0.82, radius / outer, 1.0],
        ),
    );

    if (sunOnScreen == Offset.zero) {
      return;
    }

    // The limb the Sun is behind burns much brighter than the rest of the rim.
    // This is drawn before the body itself, so the half of the blob that falls
    // across the disc is painted over and only the crescent outside survives.
    // Sat just inside the limb and scaled to the depth of the air, so it
    // reads as the rim catching the light rather than a blob stuck to the
    // side. Most of it falls on the disc and is painted over.
    final Offset hot = centre + sunOnScreen * (radius * 0.94);
    final double reach = (outer - radius) * 2.6;
    canvas.drawCircle(
      hot,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          hot,
          reach,
          <ui.Color>[
            air.withValues(alpha: 0.80 * _airOpacity),
            air.withValues(alpha: 0.0),
          ],
          <double>[0.0, 1.0],
        ),
    );
  }

  /// How dark the unlit half of a distant body is drawn, matching the
  /// renderer's own ambient so a body does not change brightness as it crosses
  /// the size at which it stops being a mesh.
  static const double _nightFraction = 0.22;

  /// Multipliers on the atmosphere's depth and opacity. Both are exaggerated:
  /// at true scale Earth's air is a pixel thick and nearly invisible.
  static const double _airSpread = 2.6;
  static const double _airOpacity = 0.42;

  Vector3 _worldPosition(CelestialBody body) =>
      bodyWorldPosition(simulation, scale, body);

  @override
  bool shouldRepaint(covariant SolarSystemPainter oldDelegate) => true;
}

class _Placed {
  const _Placed(this.body, this.mesh, this.world, this.depth, this.radius);

  final CelestialBody body;
  final MeshAsset mesh;
  final Vector3 world;
  final double depth;

  /// Drawn radius in scene units.
  final double radius;
}

/// A name waiting to be drawn, and how squarely its place faces us.
class _Label {
  const _Label(this.text, this.at, this.facing);

  final String text;
  final Offset at;
  final double facing;
}
