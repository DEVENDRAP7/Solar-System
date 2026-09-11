import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// A camera that orbits a point, driven by drag and pinch.
class OrbitCamera {
  OrbitCamera({
    Vector3? target,
    this.distance = 32.0,
    this.yaw = 0.6,
    this.pitch = 0.42,
  }) : target = target ?? Vector3.zero();

  /// The view the app opens on, and what the recentre control returns to:
  /// close enough that the planets read as discs rather than dots.
  static OrbitCamera overview() => OrbitCamera();

  /// Point the camera looks at, in scene units.
  Vector3 target;

  /// Distance from the target.
  double distance;

  /// Rotation about the vertical axis, in radians.
  double yaw;

  /// Elevation above the ecliptic, in radians.
  double pitch;

  double minDistance = 0.4;
  double maxDistance = 900.0;

  /// Vertical field of view, in radians.
  double fieldOfView = 50.0 * math.pi / 180.0;

  static const double _maxPitch = math.pi / 2 - 0.02;

  void rotate(double deltaYaw, double deltaPitch) {
    yaw += deltaYaw;
    pitch = (pitch + deltaPitch).clamp(-_maxPitch, _maxPitch);
  }

  void zoom(double factor) {
    distance = (distance / factor).clamp(minDistance, maxDistance);
  }

  /// Slide the camera across the scene, keeping its heading.
  ///
  /// This is what makes the view free: without it the camera is pinned to one
  /// point and dragging only ever circles that point.
  void pan(double dx, double dy, double viewportReference) {
    final Vector3 forward = (target - eye).normalized();
    final Vector3 right = forward.cross(Vector3(0, 1, 0));
    if (right.length2 < 1e-9) {
      return;
    }
    right.normalize();
    final Vector3 up = right.cross(forward)..normalize();

    // Move by the same world distance the finger covered on screen, so the
    // scene tracks the fingertip regardless of zoom.
    final double worldPerPixel =
        2.0 * distance * math.tan(fieldOfView / 2.0) / viewportReference;

    target = target - right * (dx * worldPerPixel) + up * (dy * worldPerPixel);
  }

  /// Ease toward another camera position, for jumping to a body.
  void easeTo(OrbitCamera other, double t) {
    target = target + (other.target - target) * t;
    distance += (other.distance - distance) * t;
    yaw += (other.yaw - yaw) * t;
    pitch += (other.pitch - pitch) * t;
  }

  /// True once this camera has essentially arrived at [other].
  bool hasArrived(OrbitCamera other) =>
      (target - other.target).length < 0.02 &&
      (distance - other.distance).abs() < 0.02;

  /// Camera position in world space.
  Vector3 get eye {
    final double cosPitch = math.cos(pitch);
    return target +
        Vector3(
          distance * cosPitch * math.sin(yaw),
          distance * math.sin(pitch),
          distance * cosPitch * math.cos(yaw),
        );
  }

  /// The camera's right-hand axis: screen-right, in world space.
  Vector3 get right => Vector3(math.cos(yaw), 0, -math.sin(yaw));

  /// World-to-view transform, with the camera looking down its own -z.
  Matrix4 get view => makeViewMatrix(eye, target, Vector3(0, 1, 0));

  /// Focal length in pixels for a viewport of [width] by [height].
  ///
  /// The field of view is applied to the shorter side of the screen. On a
  /// phone held upright that is the width, and anchoring to the height instead
  /// left the view only a few units wide — narrow enough that Earth's orbit
  /// fell outside the frame and the inner planets were never on screen.
  double focalLength(double width, double height) =>
      (math.min(width, height) / 2.0) / math.tan(fieldOfView / 2.0);

  OrbitCamera copy() => OrbitCamera(
    target: target.clone(),
    distance: distance,
    yaw: yaw,
    pitch: pitch,
  );
}
