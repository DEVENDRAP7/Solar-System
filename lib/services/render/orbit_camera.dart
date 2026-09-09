import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// A camera that orbits a point, driven by drag and pinch.
class OrbitCamera {
  OrbitCamera({
    Vector3? target,
    this.distance = 34.0,
    this.yaw = 0.6,
    this.pitch = 0.5,
  }) : target = target ?? Vector3.zero();

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

  /// World-to-view transform, with the camera looking down its own -z.
  Matrix4 get view => makeViewMatrix(eye, target, Vector3(0, 1, 0));

  /// Focal length in pixels for a viewport of [height].
  double focalLength(double height) =>
      (height / 2.0) / math.tan(fieldOfView / 2.0);

  OrbitCamera copy() => OrbitCamera(
        target: target.clone(),
        distance: distance,
        yaw: yaw,
        pitch: pitch,
      );
}
