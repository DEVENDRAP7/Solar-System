import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:vector_math/vector_math_64.dart';

import 'mesh_asset.dart';

/// Draws a textured, lit mesh with the canvas's own triangle rasteriser.
///
/// Vertices are transformed and projected in Dart, then handed to
/// [ui.Canvas.drawVertices], which is hardware accelerated by Flutter itself.
/// That means no OpenGL plugin, no native texture handshake, and no platform
/// specific renderer to go wrong.
class BodyRenderer {
  const BodyRenderer._();

  /// Draw [mesh] positioned by [model], seen through [view].
  ///
  /// [lightDirection] points from the surface toward the light, in world space.
  /// An emissive body ignores it and draws at full brightness.
  static void draw(
    ui.Canvas canvas,
    MeshAsset mesh, {
    required Matrix4 model,
    required Matrix4 view,
    required ui.Size size,
    required double focalLength,
    required Vector3 lightDirection,
    Vector3? viewDirection,
    bool emissive = false,
    double ambient = 0.16,
    double fill = 0.26,
  }) {
    final ui.Image? texture = mesh.texture;
    if (texture == null) {
      return;
    }

    final int count = mesh.vertexCount;
    final Matrix4 modelView = view * model;
    final Matrix3 normalMatrix = model.getRotation();

    final Float32List screen = Float32List(count * 2);
    final Float32List texCoords = Float32List(count * 2);
    final Int32List colors = Int32List(count);
    final Float32List depth = Float32List(count);

    final double halfWidth = size.width / 2.0;
    final double halfHeight = size.height / 2.0;

    for (int i = 0; i < count; i++) {
      final double x = mesh.positions[i * 3];
      final double y = mesh.positions[i * 3 + 1];
      final double z = mesh.positions[i * 3 + 2];

      // Transform into view space, where the camera looks down -z.
      final double vx = modelView[0] * x + modelView[4] * y + modelView[8] * z + modelView[12];
      final double vy = modelView[1] * x + modelView[5] * y + modelView[9] * z + modelView[13];
      final double vz = modelView[2] * x + modelView[6] * y + modelView[10] * z + modelView[14];

      depth[i] = vz;

      // Guard against dividing by zero for anything at or behind the eye.
      final double denominator = vz < -1e-4 ? -vz : 1e-4;
      screen[i * 2] = halfWidth + focalLength * vx / denominator;
      screen[i * 2 + 1] = halfHeight - focalLength * vy / denominator;

      texCoords[i * 2] = mesh.uvs[i * 2] * texture.width;
      texCoords[i * 2 + 1] = mesh.uvs[i * 2 + 1] * texture.height;

      double shade = 1.0;
      if (!emissive) {
        final double nx = mesh.normals[i * 3];
        final double ny = mesh.normals[i * 3 + 1];
        final double nz = mesh.normals[i * 3 + 2];

        final double wx = normalMatrix.entry(0, 0) * nx +
            normalMatrix.entry(0, 1) * ny +
            normalMatrix.entry(0, 2) * nz;
        final double wy = normalMatrix.entry(1, 0) * nx +
            normalMatrix.entry(1, 1) * ny +
            normalMatrix.entry(1, 2) * nz;
        final double wz = normalMatrix.entry(2, 0) * nx +
            normalMatrix.entry(2, 1) * ny +
            normalMatrix.entry(2, 2) * nz;

        final double lambert =
            wx * lightDirection.x + wy * lightDirection.y + wz * lightDirection.z;
        shade = ambient + (1.0 - ambient - fill) * math.max(0.0, lambert);

        // A weak light from the camera keeps whatever you are looking at
        // readable without washing out the terminator.
        if (viewDirection != null) {
          final double facing = wx * viewDirection.x +
              wy * viewDirection.y +
              wz * viewDirection.z;
          shade += fill * math.max(0.0, facing);
        }
      }

      final int level = (shade.clamp(0.0, 1.0) * 255).round();
      colors[i] = 0xFF000000 | (level << 16) | (level << 8) | level;
    }

    // Keep only front-facing triangles that are fully in front of the eye.
    // The bodies are closed convex-ish shells, so this alone resolves what is
    // in front of what, with no depth buffer to maintain.
    final Uint16List source = mesh.indices;
    final Uint16List visible = Uint16List(source.length);
    int written = 0;

    for (int t = 0; t < source.length; t += 3) {
      final int a = source[t];
      final int b = source[t + 1];
      final int c = source[t + 2];

      if (depth[a] >= 0 || depth[b] >= 0 || depth[c] >= 0) {
        continue;
      }

      final double ax = screen[a * 2];
      final double ay = screen[a * 2 + 1];
      final double area = (screen[b * 2] - ax) * (screen[c * 2 + 1] - ay) -
          (screen[c * 2] - ax) * (screen[b * 2 + 1] - ay);
      if (area <= 0) {
        continue;
      }

      visible[written++] = a;
      visible[written++] = b;
      visible[written++] = c;
    }

    if (written == 0) {
      return;
    }

    final ui.Vertices vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      screen,
      textureCoordinates: texCoords,
      colors: colors,
      indices: Uint16List.sublistView(visible, 0, written),
    );

    final ui.Paint paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..shader = ui.ImageShader(
        texture,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Matrix4.identity().storage,
        filterQuality: ui.FilterQuality.medium,
      );

    // Modulate multiplies the texture by the per-vertex shade, which is what
    // turns flat colour into a lit sphere.
    canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);
  }
}
