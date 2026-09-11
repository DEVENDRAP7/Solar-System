import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../config/view_scale.dart';
import 'solar_system_view.dart' show DragMode;

/// Toggles for what the scene shows.
class DisplayOptions extends StatelessWidget {
  const DisplayOptions({
    required this.showOrbits,
    required this.showMoons,
    required this.scaleMode,
    required this.onOrbitsChanged,
    required this.onMoonsChanged,
    required this.showBelt,
    required this.onBeltChanged,
    required this.onScaleModeChanged,
    required this.onRecenter,
    required this.dragMode,
    required this.onDragModeChanged,
    super.key,
  });

  final bool showOrbits;
  final bool showMoons;
  final ScaleMode scaleMode;
  final ValueChanged<bool> onOrbitsChanged;
  final ValueChanged<bool> onMoonsChanged;
  final bool showBelt;
  final ValueChanged<bool> onBeltChanged;
  final ValueChanged<ScaleMode> onScaleModeChanged;
  final VoidCallback onRecenter;
  final DragMode dragMode;
  final ValueChanged<DragMode> onDragModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        border: Border.all(color: AppTheme.panelBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Toggle(
            icon: dragMode == DragMode.move
                ? Icons.pan_tool_alt_rounded
                : Icons.threesixty_rounded,
            tooltip: dragMode == DragMode.move
                ? 'Dragging moves across the system'
                : 'Dragging swings the view around',
            active: dragMode == DragMode.move,
            onPressed: () => onDragModeChanged(
              dragMode == DragMode.move ? DragMode.orbit : DragMode.move,
            ),
          ),
          _Toggle(
            icon: Icons.filter_center_focus_rounded,
            tooltip: 'Back to the whole system',
            active: false,
            onPressed: onRecenter,
          ),
          _Toggle(
            icon: Icons.blur_circular_outlined,
            tooltip: 'Orbit paths',
            active: showOrbits,
            onPressed: () => onOrbitsChanged(!showOrbits),
          ),
          _Toggle(
            icon: Icons.brightness_2_outlined,
            tooltip: 'Moons',
            active: showMoons,
            onPressed: () => onMoonsChanged(!showMoons),
          ),
          _Toggle(
            icon: Icons.grain_rounded,
            tooltip: 'Asteroid belt',
            active: showBelt,
            onPressed: () => onBeltChanged(!showBelt),
          ),
          _Toggle(
            icon: Icons.straighten_rounded,
            tooltip: scaleMode == ScaleMode.explore
                ? 'Switch to true scale'
                : 'Switch to explore scale',
            active: scaleMode == ScaleMode.trueScale,
            onPressed: () => onScaleModeChanged(
              scaleMode == ScaleMode.explore
                  ? ScaleMode.trueScale
                  : ScaleMode.explore,
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        color: active ? AppTheme.accent : AppTheme.textSecondary,
      ),
    );
  }
}
