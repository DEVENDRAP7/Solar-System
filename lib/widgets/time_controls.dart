import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../providers/solar_system_provider.dart';

/// Pause, time scale and the simulated date.
class TimeControls extends StatelessWidget {
  const TimeControls({
    required this.speedIndex,
    required this.paused,
    required this.clock,
    required this.onSpeedChanged,
    required this.onTogglePaused,
    required this.onResetToNow,
    super.key,
  });

  final int speedIndex;
  final bool paused;
  final ValueListenable<DateTime> clock;
  final ValueChanged<int> onSpeedChanged;
  final VoidCallback onTogglePaused;
  final VoidCallback onResetToNow;

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String formatDate(DateTime time) {
    final DateTime utc = time.toUtc();
    final String hour = utc.hour.toString().padLeft(2, '0');
    final String minute = utc.minute.toString().padLeft(2, '0');
    return '${utc.day} ${_months[utc.month - 1]} ${utc.year}  $hour:$minute UTC';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final TimeSpeed speed = SolarSystemProvider.speeds[speedIndex];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        border: Border.all(color: AppTheme.panelBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onTogglePaused,
                tooltip: paused ? 'Play' : 'Pause',
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  color: AppTheme.accent,
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: clock,
                  builder: (BuildContext context, DateTime time, Widget? _) {
                    return Text(
                      formatDate(time),
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    );
                  },
                ),
              ),
              IconButton(
                onPressed: onResetToNow,
                tooltip: 'Back to now',
                icon: const Icon(Icons.restore_rounded,
                    color: AppTheme.textSecondary),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Text(speed.label, style: text.labelSmall),
              Expanded(
                child: Slider(
                  value: speedIndex.toDouble(),
                  min: 0,
                  max: (SolarSystemProvider.speeds.length - 1).toDouble(),
                  divisions: SolarSystemProvider.speeds.length - 1,
                  onChanged: (double value) => onSpeedChanged(value.round()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
