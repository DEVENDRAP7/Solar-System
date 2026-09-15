import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../config/view_scale.dart';
import 'glass_panel.dart';
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
    required this.showLabels,
    required this.onLabelsChanged,
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
  final bool showLabels;
  final ValueChanged<bool> onLabelsChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      radius: 20,
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
            icon: Icons.label_outline_rounded,
            tooltip: 'Names of places and moons',
            active: showLabels,
            onPressed: () => onLabelsChanged(!showLabels),
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 2),
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            // On is a lit key, off is bare: a tint alone is hard to read at
            // a glance against a scene that is itself mostly dark.
            color: active
                ? AppTheme.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 19,
            color: active ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
