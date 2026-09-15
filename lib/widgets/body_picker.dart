import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/body_catalog.dart';
import '../models/celestial_body.dart';
import 'body_orb.dart';

/// Horizontal strip for jumping straight to a body.
///
/// Lists the Sun, the planets and our Moon. The other twenty moons are reached
/// by tapping them, which keeps this from becoming a list to scroll through.
class BodyPicker extends StatelessWidget {
  const BodyPicker({
    required this.selectedKey,
    required this.onSelected,
    super.key,
  });

  final String? selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: BodyCatalog.planetsAndSun.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final CelestialBody body = BodyCatalog.planetsAndSun[index];
          final bool active = body.key == selectedKey;

          return Semantics(
            button: true,
            selected: active,
            label: body.label,
            child: GestureDetector(
              onTap: () => onSelected(body.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  border: Border.all(
                    color: active
                        ? AppTheme.accent.withValues(alpha: 0.7)
                        : Colors.transparent,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // The body itself, rather than its name in a box: a row
                    // of planets is taken in at a glance, where a row of
                    // words has to be read one at a time.
                    BodyOrb(body: body, size: active ? 30 : 26),
                    const SizedBox(height: 5),
                    Text(
                      body.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: active
                            ? AppTheme.accent
                            : AppTheme.textSecondary,
                        fontSize: 10.5,
                        letterSpacing: 0.3,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
