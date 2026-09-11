import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../config/view_scale.dart';
import '../models/asteroid_belt.dart';
import '../models/body_catalog.dart';
import '../models/celestial_body.dart';
import '../services/physics/simulation.dart';
import '../services/render/mesh_library.dart';
import '../services/render/orbit_camera.dart';
import '../services/render/solar_system_painter.dart';

/// What a one-finger drag does to the view.
enum DragMode {
  /// Swing the camera around what it is looking at.
  orbit,

  /// Slide across the system, going wherever you like.
  move,
}

/// The 3D view: gestures, the animation clock, and the painter.
class SolarSystemView extends StatefulWidget {
  const SolarSystemView({
    required this.simulation,
    required this.library,
    required this.scale,
    required this.showOrbits,
    required this.showMoons,
    required this.showBelt,
    required this.belt,
    required this.focusKey,
    required this.onTapBody,
    required this.onFrame,
    required this.onInteracting,
    required this.dragMode,
    required this.recenterRequests,
    super.key,
  });

  final SolarSystemSimulation simulation;
  final MeshLibrary library;
  final ViewScale scale;
  final bool showOrbits;
  final bool showMoons;
  final bool showBelt;
  final AsteroidBelt? belt;

  /// Body the camera should settle on, or null for the whole system.
  final String? focusKey;

  final void Function(String? key) onTapBody;
  final void Function(double deltaSeconds) onFrame;

  /// Raised while a finger is on the scene, so time can be held still.
  final void Function(bool interacting) onInteracting;

  /// What a one-finger drag does.
  final DragMode dragMode;

  /// Bumped when the view should return to the overview.
  final ValueListenable<int> recenterRequests;

  @override
  State<SolarSystemView> createState() => _SolarSystemViewState();
}

class _SolarSystemViewState extends State<SolarSystemView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  final OrbitCamera _camera = OrbitCamera();
  final List<BodyHit> _hits = <BodyHit>[];
  late final List<vm.Vector3> _stars = MeshLibrary.makeStars(1200);

  OrbitCamera? _destination;
  Duration _last = Duration.zero;
  double _zoomStart = 1.0;
  Size _viewport = Size.zero;

  /// True once a gesture has involved more than one finger.
  bool _multiTouch = false;

  /// Radians of rotation per pixel dragged. A full swipe across a phone turns
  /// the view about two thirds of the way round, which is quick without being
  /// uncontrollable.
  static const double _rotateSpeed = 0.0032;

  /// Scale changes smaller than this are treated as noise rather than a pinch.
  static const double _zoomDeadzone = 0.004;

  /// While true the camera keeps a selected body centred. Panning away turns
  /// it off, which is what lets you wander off on your own.
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    widget.recenterRequests.addListener(_recenter);
  }

  void _recenter() {
    _following = false;
    _destination = OrbitCamera.overview();
  }

  void _onTick(Duration elapsed) {
    final double delta = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    widget.onFrame(delta.clamp(0.0, 0.25));

    final OrbitCamera? destination = _destination;
    final String? focus = widget.focusKey;

    if (destination != null && focus != null) {
      // Retarget as we travel, so the camera arrives where the body is now.
      destination.target = _targetFor(focus);
    }

    if (destination != null) {
      _camera.easeTo(destination, 0.12);
      if (_camera.hasArrived(destination)) {
        _destination = null;
      }
    } else if (_following && focus != null) {
      // Keep a selected body centred once the camera has arrived.
      _camera.target = _targetFor(focus);
    }

    _frame.value++;
  }

  vm.Vector3 _targetFor(String key) {
    final CelestialBody? body = BodyCatalog.byKey(key);
    if (body == null) {
      return vm.Vector3.zero();
    }
    return bodyWorldPosition(widget.simulation, widget.scale, body);
  }

  @override
  void didUpdateWidget(SolarSystemView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusKey != oldWidget.focusKey) {
      _moveToFocus();
    }
  }

  void _moveToFocus() {
    final String? key = widget.focusKey;
    if (key == null) {
      _following = false;
      _destination = null;
      return;
    }
    _following = true;

    final CelestialBody? body = BodyCatalog.byKey(key);
    if (body == null) {
      return;
    }

    final double radius = widget.scale.bodyRadius(body.radiusKm);
    _destination = OrbitCamera(
      target: _targetFor(key),
      distance: (radius * 7.0).clamp(0.6, 120.0),
      yaw: _camera.yaw,
      pitch: _camera.pitch,
    );
  }

  void _handleTap(TapUpDetails details) {
    final Offset point = details.localPosition;
    String? best;
    double bestDistance = double.infinity;

    for (final BodyHit hit in _hits) {
      final double distance = (hit.center - point).distance;
      if (distance <= hit.radius && distance < bestDistance) {
        best = hit.key;
        bestDistance = distance;
      }
    }
    widget.onTapBody(best);
  }

  @override
  void dispose() {
    widget.recenterRequests.removeListener(_recenter);
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _zoomStart = 1.0;
    _multiTouch = details.pointerCount > 1;
    // Hold the clock while a finger is down. Without this a planet turns and
    // drifts away as you try to look at it, and its far side stays hidden.
    widget.onInteracting(true);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Once a gesture has had two fingers on it, it stays a two-finger gesture
    // until every finger lifts. Reading the count live means that lifting one
    // finger at the end of a pinch turns the last moments of it into a spin.
    if (details.pointerCount > 1) {
      _multiTouch = true;
    }

    final Offset delta = details.focalPointDelta;

    if (_multiTouch) {
      // Pinch and drag together. The scale reading is never perfectly steady
      // during a two-finger drag, so small changes are ignored — otherwise
      // every attempt to move the view zooms it slightly as well.
      final double step = details.scale / _zoomStart;
      if ((step - 1.0).abs() > _zoomDeadzone) {
        _zoomStart = details.scale;
        _camera.zoom(step);
      }
      _movePan(delta);
    } else if (widget.dragMode == DragMode.move) {
      _movePan(delta);
    } else {
      _camera.rotate(-delta.dx * _rotateSpeed, delta.dy * _rotateSpeed);
    }

    _destination = null;
  }

  void _movePan(Offset delta) {
    if (delta == Offset.zero || _viewport.height <= 0) {
      return;
    }
    _camera.pan(delta.dx, delta.dy, _viewport.shortestSide);
    // Moving away from a body stops the camera following it.
    _following = false;
  }

  void _handleScaleEnd(ScaleEndDetails details) => widget.onInteracting(false);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewport = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _handleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: CustomPaint(
            size: Size.infinite,
            painter: SolarSystemPainter(
              simulation: widget.simulation,
              camera: _camera,
              meshes: widget.library.meshes,
              scale: widget.scale,
              stars: _stars,
              hits: _hits,
              showOrbits: widget.showOrbits,
              showMoons: widget.showMoons,
              belt: widget.belt,
              showBelt: widget.showBelt,
              repaint: _frame,
            ),
          ),
        );
      },
    );
  }
}
