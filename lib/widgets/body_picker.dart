import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/body_catalog.dart';
import '../models/celestial_body.dart';

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
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: BodyCatalog.planetsAndSun.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final CelestialBody body = BodyCatalog.planetsAndSun[index];
          final bool active = body.key == selectedKey;

          return GestureDetector(
            onTap: () => onSelected(body.key),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.accent.withValues(alpha: 0.22)
                    : AppTheme.panel,
                border: Border.all(
                  color: active ? AppTheme.accent : AppTheme.panelBorder,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                body.label,
                style: text.titleMedium?.copyWith(
                  color: active ? AppTheme.accent : AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
