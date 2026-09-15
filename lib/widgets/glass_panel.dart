import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The surface every control sits on.
///
/// Deliberately not a real blur: a BackdropFilter over a scene that is redrawn
/// sixty times a second costs a full-screen GPU pass every frame, and this is
/// a phone drawing a solar system in Dart. A translucent fill with a lit top
/// edge and a shadow beneath reads as glass at a fraction of the price.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 18,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xF2141B2B), Color(0xF20B0F19)],
        ),
        border: Border.all(color: AppTheme.panelBorder),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
