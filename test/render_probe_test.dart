import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/services/render/body_renderer.dart';
import 'package:solar_system_app/services/render/mesh_asset.dart';
import 'package:vector_math/vector_math_64.dart';

/// Renders bodies to a real PNG so the output can be looked at rather than
/// assumed. Writes into build/render_probe/.
void main() {
  testWidgets('renders bodies to an image', (WidgetTester tester) async {
    await tester.runAsync(() async {
      const ui.Size size = ui.Size(900, 300);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
        ui.Paint()..color = const ui.Color(0xFF05060A),
      );

      final Matrix4 view = Matrix4.identity()..setTranslationRaw(0, 0, -4.2);
      final Vector3 light = Vector3(0.6, 0.35, 0.72)..normalize();

      final List<String> keys = <String>['earth', 'mars', 'jupiter'];
      for (int i = 0; i < keys.length; i++) {
        final Uint8List bytes =
            await File('assets/models/${keys[i]}.glb').readAsBytes();
        final MeshAsset mesh = await GlbReader.parse(bytes);

        expect(mesh.vertexCount, greaterThan(0), reason: keys[i]);
        expect(mesh.texture, isNotNull, reason: '${keys[i]} texture');

        final Matrix4 model = Matrix4.identity()
          ..setTranslationRaw((i - 1) * 2.6, 0, 0)
          ..rotateY(0.7);

        BodyRenderer.draw(
          canvas,
          mesh,
          model: model,
          view: view,
          size: size,
          focalLength: 420,
          lightDirection: light,
        );
      }

      final ui.Picture picture = recorder.endRecording();
      final ui.Image image =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final ByteData? png =
          await image.toByteData(format: ui.ImageByteFormat.png);

      expect(png, isNotNull);
      final Directory out = Directory('build/render_probe')
        ..createSync(recursive: true);
      File('${out.path}/bodies.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
