import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../config/view_scale.dart';
import '../models/asteroid_belt.dart';
import '../models/body_catalog.dart';
import '../models/celestial_body.dart';
import '../services/physics/simulation.dart';
import '../services/render/body_inspector.dart';
import '../services/render/mesh_library.dart';
import '../services/render/orbit_camera.dart';
import '../services/render/solar_system_painter.dart';

/// What a drag is moving: the camera around the scene, the camera across it,
/// or the body the camera is looking at.
enum _Drag { orbit, slide, turnBody }

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
    this.inspector,
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

  /// The hand-turn applied to a selected body. Supplied by tests; the view
  /// makes its own otherwise.
  final BodyInspector? inspector;

  @override
  State<SolarSystemView> createState() => _SolarSystemViewState();
}

class _SolarSystemViewState extends State<SolarSystemView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  final OrbitCamera _camera = OrbitCamera();
  late final BodyInspector _inspector = widget.inspector ?? BodyInspector();
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

  /// Speed left over from the last drag, in pixels per second, and what it is
  /// moving. The view keeps going after the finger lifts and slows to a stop,
  /// so a flick across the system carries instead of stopping dead.
  Offset _glide = Offset.zero;
  _Drag _glideKind = _Drag.orbit;

  /// What fraction of the glide's speed survives each second. Low enough to
  /// settle in about a second, high enough that a throw goes somewhere.
  static const double _glideDecay = 0.06;

  /// Below this many pixels a second the glide has arrived.
  static const double _glideFloor = 12.0;

  /// Flicks faster than this are treated as a throw rather than the small
  /// involuntary movement of lifting a finger off the glass.
  static const double _glideThreshold = 140.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    widget.recenterRequests.addListener(_recenter);
    // A body can already be selected the first time the view is built — after
    // a restart, say. Only a change in the selection reaches didUpdateWidget,
    // so without this the camera would never go to it.
    if (widget.focusKey != null) {
      _moveToFocus();
    }
  }

  void _recenter() {
    _following = false;
    _inspector.focus(null);
    _destination = OrbitCamera.overview();
  }

  void _onTick(Duration elapsed) {
    final double delta = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    widget.onFrame(delta.clamp(0.0, 0.25));

    _coast(delta);

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

  /// Carry the last drag on for a moment, slowing as it goes.
  void _coast(double seconds) {
    if (_glide == Offset.zero || seconds <= 0) {
      return;
    }
    if (_glide.distance < _glideFloor) {
      _glide = Offset.zero;
      return;
    }
    _apply(_glide * seconds, _glideKind);
    _glide = _glide * math.pow(_glideDecay, seconds).toDouble();
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
      _inspector.focus(null);
      _destination = null;
      return;
    }
    _following = true;
    _inspector.focus(key);

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
    // Tapping the body you are already on brings the camera back to it after
    // you have wandered off, which the parent cannot do for you: the selection
    // has not changed, so nothing else would tell the view to return.
    if (best != null && best == widget.focusKey && !_following) {
      _moveToFocus();
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
    // A finger on the glass stops the view where it is, the way catching a
    // spinning globe does.
    _glide = Offset.zero;
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
        _destination = null;
      }
    }
    _apply(delta, _dragKind);
  }

  /// What the drag in progress is moving.
  _Drag get _dragKind {
    if (_multiTouch || widget.dragMode == DragMode.move) {
      return _Drag.slide;
    }
    // A body is selected, so a drag turns that body rather than flying the
    // camera around it. The camera does not move, so the planets, orbits and
    // belt behind it stay put while its far side comes into view.
    return _inspector.isActive ? _Drag.turnBody : _Drag.orbit;
  }

  /// Move the view by [delta] pixels, however that drag is being spent.
  ///
  /// The finger and the glide that follows it both come through here, so a
  /// throw carries on doing exactly what the hand was doing.
  void _apply(Offset delta, _Drag kind) {
    switch (kind) {
      case _Drag.slide:
        _movePan(delta);
      case _Drag.turnBody:
        _inspector.turn(delta.dx * _rotateSpeed, delta.dy * _rotateSpeed);
      case _Drag.orbit:
        _camera.rotate(-delta.dx * _rotateSpeed, delta.dy * _rotateSpeed);
        _destination = null;
    }
  }

  void _movePan(Offset delta) {
    if (delta == Offset.zero || _viewport.height <= 0) {
      return;
    }
    _camera.pan(delta.dx, delta.dy, _viewport.shortestSide);
    _destination = null;
    // Moving away from a body stops the camera following it, and hands the
    // drag back to the camera so the whole system can be explored again.
    _following = false;
    _inspector.focus(null);
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    widget.onInteracting(false);

    final Offset thrown = details.velocity.pixelsPerSecond;
    if (thrown.distance >= _glideThreshold) {
      _glide = thrown;
      _glideKind = _dragKind;
    } else {
      _glide = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewport = constraints.biggest;
        return Listener(
          // A finger touching the glass stops the glide at once, the way
          // catching a spinning globe does. It has to be the raw pointer: the
          // scale gesture does not start until the arena resolves, so a finger
          // resting still would let the view carry on sliding underneath it.
          onPointerDown: (PointerDownEvent _) => _glide = Offset.zero,
          child: GestureDetector(
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
                inspector: _inspector,
                repaint: _frame,
              ),
            ),
          ),
        );
      },
    );
  }
}
