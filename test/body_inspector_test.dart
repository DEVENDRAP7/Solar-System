import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/services/render/body_inspector.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('nothing turns until a body is selected', () {
    final BodyInspector inspector = BodyInspector();

    inspector.turn(1.0, 0.5);

    expect(inspector.isActive, isFalse);
    expect(inspector.yaw, 0.0);
    expect(inspector.spinFor('earth'), 0.0);
  });

  test('only the selected body is turned', () {
    final BodyInspector inspector = BodyInspector()..focus('mars');
    inspector.turn(0.7, 0.0);

    expect(inspector.spinFor('mars'), closeTo(0.7, 1e-9));
    expect(inspector.spinFor('earth'), 0.0);
    expect(inspector.tipFor('earth', Vector3(1, 0, 0)), Matrix4.identity());
  });

  test('selecting a different body starts it square on', () {
    final BodyInspector inspector = BodyInspector()..focus('mars');
    inspector.turn(1.2, 0.4);
    inspector.focus('venus');

    expect(inspector.yaw, 0.0);
    expect(inspector.pitch, 0.0);
    expect(inspector.spinFor('mars'), 0.0);
  });

  test('the tip stops short of the pole however hard it is dragged', () {
    final BodyInspector inspector = BodyInspector()..focus('jupiter');

    inspector.turn(0.0, 40.0);
    expect(inspector.pitch, lessThan(math.pi / 2));
    expect(inspector.pitch, greaterThan(1.5));

    inspector.turn(0.0, -80.0);
    expect(inspector.pitch, greaterThan(-math.pi / 2));
  });

  test('the tip rotates about the axis it is given', () {
    final BodyInspector inspector = BodyInspector()..focus('earth');
    inspector.turn(0.0, math.pi / 2);

    // Dragging down tips the north pole toward the viewer: with screen-right
    // as the axis, the body's up axis swings round to point at the camera.
    final Vector3 up = inspector
        .tipFor('earth', Vector3(1, 0, 0))
        .transformed3(Vector3(0, 1, 0));

    // The tip stops a hair short of the pole, so this is very nearly, but not
    // exactly, straight at the camera.
    expect(up.x, closeTo(0.0, 1e-6));
    expect(up.y, closeTo(0.02, 1e-3));
    expect(up.z, closeTo(1.0, 1e-3));
  });

  test('an unnormalised axis still gives a pure rotation', () {
    final BodyInspector inspector = BodyInspector()..focus('saturn');
    inspector.turn(0.0, 0.6);

    final Vector3 turned = inspector
        .tipFor('saturn', Vector3(3, 0, 0))
        .transformed3(Vector3(0, 1, 0));

    expect(turned.length, closeTo(1.0, 1e-9));
  });
}
