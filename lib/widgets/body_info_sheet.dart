import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/celestial_body.dart';
import 'body_orb.dart';

/// Details panel for the selected body.
class BodyInfoSheet extends StatelessWidget {
  const BodyInfoSheet({required this.body, required this.onClose, super.key});

  final CelestialBody body;
  final VoidCallback onClose;

  static String describeType(BodyType type) {
    switch (type) {
      case BodyType.star:
        return 'Star';
      case BodyType.terrestrial:
        return 'Terrestrial planet';
      case BodyType.gasGiant:
        return 'Gas giant';
      case BodyType.iceGiant:
        return 'Ice giant';
      case BodyType.moon:
        return 'Moon';
    }
  }

  /// Rotation period as a readable string, noting retrograde spin.
  static String describeRotation(double hours) {
    final double magnitude = hours.abs();
    final String value = magnitude < 48
        ? '${magnitude.toStringAsFixed(1)} hours'
        : '${(magnitude / 24).toStringAsFixed(1)} days';
    return hours < 0 ? '$value (retrograde)' : value;
  }

  static String describePeriod(double? days) {
    if (days == null) {
      return '—';
    }
    if (days < 400) {
      return '${days.toStringAsFixed(1)} days';
    }
    return '${(days / 365.256363).toStringAsFixed(1)} years';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        border: Border(top: BorderSide(color: AppTheme.panelBorder)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 12, top: 2),
                  child: BodyOrb(body: body, size: 40),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(body.label, style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        describeType(body.type).toUpperCase(),
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body.description, style: text.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 26,
              runSpacing: 14,
              children: <Widget>[
                _Fact(label: 'Radius', value: '${body.radiusKm.round()} km'),
                _Fact(
                  label: 'Day',
                  value: describeRotation(body.rotationHours),
                ),
                if (body.orbitalPeriodDays != null)
                  _Fact(
                    label: 'Year',
                    value: describePeriod(body.orbitalPeriodDays),
                  ),
                _Fact(
                  label: 'Axial tilt',
                  value: '${body.axialTiltDeg.toStringAsFixed(1)}°',
                ),
                if (body.gravity != null)
                  _Fact(
                    label: 'Gravity',
                    value: '${body.gravity!.toStringAsFixed(1)} m/s²',
                  ),
                if (body.meanTemperatureC != null)
                  _Fact(
                    label: 'Mean temp',
                    value: '${body.meanTemperatureC!.round()}°C',
                  ),
                if (body.moonCount > 0)
                  _Fact(label: 'Moons', value: '${body.moonCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: text.labelSmall),
        const SizedBox(height: 3),
        Text(value, style: text.titleMedium),
      ],
    );
  }
}
