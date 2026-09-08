import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

import '../config/theme.dart';
import '../models/celestial_body.dart';
import '../providers/solar_system_provider.dart';
import '../widgets/body_info_sheet.dart';
import '../widgets/body_picker.dart';
import '../widgets/display_options.dart';
import '../widgets/time_controls.dart';

/// The main screen: the 3D scene with its controls layered over it.
class SolarSystemScreen extends StatefulWidget {
  const SolarSystemScreen({super.key});

  @override
  State<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends State<SolarSystemScreen> {
  late final SolarSystemProvider _provider;
  late final three.ThreeJS _viewer;

  /// Where the current pointer gesture started, so a drag that orbits the
  /// camera is not mistaken for a tap that selects a body.
  Offset? _pointerDownAt;

  static const double _tapSlop = 12.0;

  @override
  void initState() {
    super.initState();
    _provider = SolarSystemProvider();
    _viewer = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setupScene,
    );
  }

  Future<void> _setupScene() async {
    await _provider.scene.setup(_viewer);
    _viewer.addAnimationEvent(_provider.onFrame);
  }

  @override
  void dispose() {
    _viewer.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _handlePointerUp(PointerUpEvent event, Size size) {
    final Offset? start = _pointerDownAt;
    _pointerDownAt = null;
    if (start == null || (event.localPosition - start).distance > _tapSlop) {
      return;
    }

    final String? key = _provider.scene.bodyAt(event.localPosition, size);
    if (key != null) {
      _provider.select(key);
    } else if (_provider.selectedKey != null) {
      _provider.clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AnimatedBuilder(
        animation: _provider,
        builder: (BuildContext context, Widget? _) {
          final CelestialBody? selected = _provider.selected;

          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Size size = constraints.biggest;

              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    // Listener rather than GestureDetector: it observes
                    // pointers without entering the gesture arena, so the
                    // camera controls still receive every drag.
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (PointerDownEvent event) =>
                          _pointerDownAt = event.localPosition,
                      onPointerUp: (PointerUpEvent event) =>
                          _handlePointerUp(event, size),
                      child: _viewer.build(),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    top: MediaQuery.of(context).padding.top + 12,
                    child: DisplayOptions(
                      showOrbits: _provider.showOrbits,
                      showMoons: _provider.showMoons,
                      scaleMode: _provider.scaleMode,
                      onOrbitsChanged: _provider.setOrbitsVisible,
                      onMoonsChanged: _provider.setMoonsVisible,
                      onScaleModeChanged: _provider.setScaleMode,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (selected == null) ...<Widget>[
                          BodyPicker(
                            selectedKey: _provider.selectedKey,
                            onSelected: _provider.select,
                          ),
                          const SizedBox(height: 10),
                          TimeControls(
                            speedIndex: _provider.speedIndex,
                            paused: _provider.paused,
                            clock: _provider.clock,
                            onSpeedChanged: _provider.setSpeedIndex,
                            onTogglePaused: _provider.togglePaused,
                            onResetToNow: _provider.resetToNow,
                          ),
                        ] else
                          BodyInfoSheet(
                            body: selected,
                            onClose: _provider.clearSelection,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
