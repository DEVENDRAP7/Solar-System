import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// The extra turn the user has put on the body they are looking at.
///
/// While a body is selected, a one-finger drag turns *that body* on the spot.
/// Swinging the camera around it instead — which is what the view used to do —
/// is right for the system view but wrong close up: circling a planet drags
/// the whole sky behind it across the screen, so the other planets, the orbit
/// rings and the belt all appear to swing round as well. Turning the body
/// leaves the background exactly where it was, which is what "turn this planet
/// round and look at the far side" should do.
class BodyInspector {
  String? _key;

  /// Turn about the body's own axis, in radians.
  double yaw = 0.0;

  /// Tip toward or away from the camera, in radians.
  double pitch = 0.0;

  /// Stop just short of the pole, so the body never tips past upside down.
  static const double _maxPitch = math.pi / 2 - 0.02;

  /// The body being turned, or null when a drag should move the camera.
  String? get key => _key;

  bool get isActive => _key != null;

  /// Start turning [key] from square on, or stop turning anything at all.
  void focus(String? key) {
    if (key == _key) {
      return;
    }
    _key = key;
    yaw = 0.0;
    pitch = 0.0;
  }

  void turn(double deltaYaw, double deltaPitch) {
    if (_key == null) {
      return;
    }
    yaw += deltaYaw;
    pitch = (pitch + deltaPitch).clamp(-_maxPitch, _maxPitch);
  }

  /// Extra spin for [bodyKey], to add to the body's own rotation.
  double spinFor(String bodyKey) => bodyKey == _key ? yaw : 0.0;

  /// Tip for [bodyKey], about the camera's [right] axis.
  ///
  /// This one is applied outside the axial tilt so that dragging up and down
  /// always brings the poles into view, whichever way the body leans.
  Matrix4 tipFor(String bodyKey, Vector3 right) {
    if (bodyKey != _key || pitch == 0.0 || right.length2 < 1e-9) {
      return Matrix4.identity();
    }
    return Matrix4.identity()..setRotation(
      Quaternion.axisAngle(right.normalized(), pitch).asRotationMatrix(),
    );
  }
}
