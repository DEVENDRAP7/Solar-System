import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// A mesh and its texture, read straight out of a glTF binary.
///
/// The models are simple by construction — one mesh, one material, float
/// positions, normals and texture coordinates with 16-bit indices — so reading
/// them directly is a few dozen lines and avoids depending on a loader.
/// Textures are decoded by the engine rather than in Dart, which is both far
/// faster and how they end up as something the canvas can sample.
class MeshAsset {
  const MeshAsset({
    required this.positions,
    required this.normals,
    required this.uvs,
    required this.indices,
    this.texture,
    this.averageColour = const ui.Color(0xFFBFC6D2),
  });

  /// Vertex positions, three floats each.
  final Float32List positions;

  /// Vertex normals, three floats each.
  final Float32List normals;

  /// Texture coordinates, two floats each.
  final Float32List uvs;

  /// Triangle indices.
  final Uint16List indices;

  /// Decoded base colour texture.
  final ui.Image? texture;

  /// The body's overall colour, used to draw it as a point of light when it is
  /// too far away to be worth triangles.
  final ui.Color averageColour;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

/// Reads a `.glb` file.
class GlbReader {
  const GlbReader._();

  static const int _magic = 0x46546C67;
  static const int _jsonChunk = 0x4E4F534A;
  static const int _binChunk = 0x004E4942;

  static const int _componentUnsignedShort = 5123;
  static const int _componentUnsignedInt = 5125;
  static const int _componentFloat = 5126;

  static Future<MeshAsset> parse(Uint8List bytes) async {
    final ByteData data = ByteData.sublistView(bytes);
    if (data.getUint32(0, Endian.little) != _magic) {
      throw const FormatException('not a glb file');
    }

    final int length = data.getUint32(8, Endian.little);
    Map<String, dynamic>? gltf;
    Uint8List? binary;

    int offset = 12;
    while (offset + 8 <= length) {
      final int chunkLength = data.getUint32(offset, Endian.little);
      final int chunkType = data.getUint32(offset + 4, Endian.little);
      final int start = offset + 8;

      if (chunkType == _jsonChunk) {
        gltf = json.decode(utf8.decode(bytes.sublist(start, start + chunkLength)))
            as Map<String, dynamic>;
      } else if (chunkType == _binChunk) {
        binary = Uint8List.sublistView(bytes, start, start + chunkLength);
      }
      offset = start + chunkLength;
    }

    if (gltf == null || binary == null) {
      throw const FormatException('glb is missing its json or binary chunk');
    }

    final Map<String, dynamic> primitive =
        ((gltf['meshes'] as List<dynamic>).first
                as Map<String, dynamic>)['primitives'][0]
            as Map<String, dynamic>;
    final Map<String, dynamic> attributes =
        primitive['attributes'] as Map<String, dynamic>;

    final Float32List positions =
        _readFloats(gltf, binary, attributes['POSITION'] as int, 3);
    final Float32List normals = attributes.containsKey('NORMAL')
        ? _readFloats(gltf, binary, attributes['NORMAL'] as int, 3)
        : Float32List(positions.length);
    final Float32List uvs = attributes.containsKey('TEXCOORD_0')
        ? _readFloats(gltf, binary, attributes['TEXCOORD_0'] as int, 2)
        : Float32List((positions.length ~/ 3) * 2);
    final Uint16List indices = _readIndices(gltf, binary, primitive['indices'] as int);

    final _Surface surface = await _readBaseColour(gltf, binary, primitive);

    return MeshAsset(
      positions: positions,
      normals: normals,
      uvs: uvs,
      indices: indices,
      texture: surface.image,
      averageColour: surface.average,
    );
  }

  static Map<String, dynamic> _view(Map<String, dynamic> gltf, int index) =>
      (gltf['bufferViews'] as List<dynamic>)[index] as Map<String, dynamic>;

  static Float32List _readFloats(
    Map<String, dynamic> gltf,
    Uint8List binary,
    int accessorIndex,
    int components,
  ) {
    final Map<String, dynamic> accessor =
        (gltf['accessors'] as List<dynamic>)[accessorIndex]
            as Map<String, dynamic>;
    if (accessor['componentType'] != _componentFloat) {
      throw const FormatException('expected float vertex data');
    }

    final Map<String, dynamic> view = _view(gltf, accessor['bufferView'] as int);
    final int base = (view['byteOffset'] as int? ?? 0) +
        (accessor['byteOffset'] as int? ?? 0);
    final int count = accessor['count'] as int;
    final int stride = view['byteStride'] as int? ?? components * 4;

    final ByteData data = ByteData.sublistView(binary);
    final Float32List out = Float32List(count * components);
    for (int i = 0; i < count; i++) {
      for (int c = 0; c < components; c++) {
        out[i * components + c] =
            data.getFloat32(base + i * stride + c * 4, Endian.little);
      }
    }
    return out;
  }

  static Uint16List _readIndices(
    Map<String, dynamic> gltf,
    Uint8List binary,
    int accessorIndex,
  ) {
    final Map<String, dynamic> accessor =
        (gltf['accessors'] as List<dynamic>)[accessorIndex]
            as Map<String, dynamic>;
    final Map<String, dynamic> view = _view(gltf, accessor['bufferView'] as int);
    final int base = (view['byteOffset'] as int? ?? 0) +
        (accessor['byteOffset'] as int? ?? 0);
    final int count = accessor['count'] as int;
    final int componentType = accessor['componentType'] as int;

    final ByteData data = ByteData.sublistView(binary);
    final Uint16List out = Uint16List(count);
    for (int i = 0; i < count; i++) {
      out[i] = switch (componentType) {
        _componentUnsignedShort => data.getUint16(base + i * 2, Endian.little),
        _componentUnsignedInt => data.getUint32(base + i * 4, Endian.little),
        _ => data.getUint8(base + i),
      };
    }
    return out;
  }

  static Future<_Surface> _readBaseColour(
    Map<String, dynamic> gltf,
    Uint8List binary,
    Map<String, dynamic> primitive,
  ) async {
    final int? materialIndex = primitive['material'] as int?;
    if (materialIndex == null) {
      return const _Surface(null, ui.Color(0xFFBFC6D2));
    }

    final Map<String, dynamic> material =
        (gltf['materials'] as List<dynamic>)[materialIndex]
            as Map<String, dynamic>;
    final Map<String, dynamic>? pbr =
        material['pbrMetallicRoughness'] as Map<String, dynamic>?;

    // Emissive bodies carry their colour on the emissive channel instead.
    final Map<String, dynamic>? textureRef =
        (pbr?['baseColorTexture'] ?? material['emissiveTexture'])
            as Map<String, dynamic>?;
    if (textureRef == null) {
      return const _Surface(null, ui.Color(0xFFBFC6D2));
    }

    final Map<String, dynamic> texture =
        (gltf['textures'] as List<dynamic>)[textureRef['index'] as int]
            as Map<String, dynamic>;
    final Map<String, dynamic> image =
        (gltf['images'] as List<dynamic>)[texture['source'] as int]
            as Map<String, dynamic>;

    final Map<String, dynamic> view = _view(gltf, image['bufferView'] as int);
    final int start = view['byteOffset'] as int? ?? 0;
    final int length = view['byteLength'] as int;

    final Uint8List encoded =
        Uint8List.sublistView(binary, start, start + length);
    final ui.Codec codec = await ui.instantiateImageCodec(encoded);
    final ui.FrameInfo frame = await codec.getNextFrame();

    return _Surface(frame.image, await _averageOf(encoded));
  }

  /// The mean colour of a map, taken from a thumbnail so it costs almost
  /// nothing: the engine decodes straight to the smaller size.
  static Future<ui.Color> _averageOf(Uint8List encoded) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        encoded,
        targetWidth: 8,
        targetHeight: 4,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ByteData? pixels = await frame.image
          .toByteData(format: ui.ImageByteFormat.rawRgba);
      frame.image.dispose();

      if (pixels == null) {
        return const ui.Color(0xFFBFC6D2);
      }

      int red = 0;
      int green = 0;
      int blue = 0;
      final int count = pixels.lengthInBytes ~/ 4;
      for (int i = 0; i < count; i++) {
        red += pixels.getUint8(i * 4);
        green += pixels.getUint8(i * 4 + 1);
        blue += pixels.getUint8(i * 4 + 2);
      }

      // Lifted well above the map's own average: a point of light stands for
      // the whole sunlit face, not the dim mean of a map that is half night.
      double lift(int total) =>
          ((total / count) * 1.7).clamp(70.0, 255.0);

      return ui.Color.fromARGB(
        255,
        lift(red).round(),
        lift(green).round(),
        lift(blue).round(),
      );
    } catch (_) {
      return const ui.Color(0xFFBFC6D2);
    }
  }
}

/// A body's surface map and its overall colour.
class _Surface {
  const _Surface(this.image, this.average);

  final ui.Image? image;
  final ui.Color average;
}
