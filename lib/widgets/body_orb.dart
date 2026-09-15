import 'package:flutter/material.dart';

import '../models/celestial_body.dart';

/// A small lit sphere standing for a body, for use in the interface.
///
/// The scene's own meshes are far too heavy to put in a list — each is five
/// thousand triangles and a two-thousand-pixel map — so this is a painted
/// stand-in: the body's real colour, lit from one side, with its air around it
/// if it has any. At sixteen pixels that is indistinguishable from the real
/// thing, and it turns a row of words into a row of planets.
class BodyOrb extends StatelessWidget {
  const BodyOrb({required this.body, this.size = 22, super.key});

  final CelestialBody body;
  final double size;

  /// Roughly what each body looks like from outside, for a swatch this small.
  static const Map<String, List<Color>> _colours = <String, List<Color>>{
    'sun': <Color>[Color(0xFFFFF3B0), Color(0xFFFFA726), Color(0xFFE65100)],
    'mercury': <Color>[Color(0xFFBDB4AA), Color(0xFF8A8078), Color(0xFF453F3A)],
    'venus': <Color>[Color(0xFFF8E7BE), Color(0xFFD9B978), Color(0xFF7A6437)],
    'earth': <Color>[Color(0xFF8FD0F0), Color(0xFF2E6FB8), Color(0xFF10294D)],
    'moon': <Color>[Color(0xFFE4E2DE), Color(0xFF9A978F), Color(0xFF3E3C39)],
    'mars': <Color>[Color(0xFFE8A178), Color(0xFFB4562C), Color(0xFF4A1E10)],
    'jupiter': <Color>[Color(0xFFEBD3B0), Color(0xFFC08A55), Color(0xFF4F3320)],
    'saturn': <Color>[Color(0xFFF2E1B8), Color(0xFFCBA96A), Color(0xFF55452A)],
    'uranus': <Color>[Color(0xFFC8F2F2), Color(0xFF7FC6CC), Color(0xFF2C5A61)],
    'neptune': <Color>[Color(0xFF9CC2F5), Color(0xFF3E6FC4), Color(0xFF16305C)],
  };

  static const List<Color> _unknown = <Color>[
    Color(0xFFCFD6E2),
    Color(0xFF8A93A5),
    Color(0xFF3A4150),
  ];

  @override
  Widget build(BuildContext context) {
    final List<Color> colours = _colours[body.key] ?? _unknown;
    final Color? air = body.atmosphere;
    final bool isStar = body.isStar;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // The rim of air, or a star's glow.
          if (air != null || isStar)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: (isStar ? const Color(0xFFFFB74D) : air!).withValues(
                      alpha: isStar ? 0.75 : 0.45,
                    ),
                    blurRadius: size * (isStar ? 0.5 : 0.3),
                    spreadRadius: size * (isStar ? 0.06 : 0.02),
                  ),
                ],
              ),
            ),
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                // Off-centre, so the light comes from somewhere and the body
                // reads as a sphere rather than a circle.
                center: const Alignment(-0.42, -0.42),
                radius: isStar ? 0.95 : 0.85,
                colors: colours,
                stops: const <double>[0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Saturn, and only Saturn, is unmistakable by its rings.
          if (body.ringModelAsset != null)
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(colours.first),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.38);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 1.34,
        height: size.height * 0.34,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.1
        ..color = colour.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.colour != colour;
}
