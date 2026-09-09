import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/celestial_body.dart';
import '../providers/solar_system_provider.dart';
import '../widgets/body_info_sheet.dart';
import '../widgets/body_picker.dart';
import '../widgets/display_options.dart';
import '../widgets/scene_loading.dart';
import '../widgets/solar_system_view.dart';
import '../widgets/time_controls.dart';

/// The main screen: the 3D view with its controls layered over it.
class SolarSystemScreen extends StatefulWidget {
  const SolarSystemScreen({super.key});

  @override
  State<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends State<SolarSystemScreen> {
  late final SolarSystemProvider _provider;
  bool _ready = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _provider = SolarSystemProvider();
    _load();
  }

  Future<void> _load() async {
    try {
      await _provider.load();
    } catch (error) {
      _loadError = error.toString();
    }
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: SceneLoading(status: _provider.library.status),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AnimatedBuilder(
        animation: _provider,
        builder: (BuildContext context, Widget? _) {
          final CelestialBody? selected = _provider.selected;

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: SolarSystemView(
                  simulation: _provider.simulation,
                  library: _provider.library,
                  scale: _provider.scale,
                  showOrbits: _provider.showOrbits,
                  showMoons: _provider.showMoons,
                  focusKey: _provider.selectedKey,
                  onTapBody: _provider.select,
                  onFrame: _provider.onFrame,
                  onInteracting: _provider.setInteracting,
                  recenterRequests: _provider.recenterRequests,
                ),
              ),
              if (_provider.library.errors.isNotEmpty || _loadError != null)
                Positioned(
                  left: 12,
                  right: 64,
                  top: MediaQuery.of(context).padding.top + 12,
                  child: _LoadErrors(
                    errors: <String>[
                      ?_loadError,
                      ..._provider.library.errors,
                    ],
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
                  onRecenter: _provider.recenter,
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
      ),
    );
  }
}

/// Shows what failed to load, so a partly built scene explains itself.
class _LoadErrors extends StatelessWidget {
  const _LoadErrors({required this.errors});

  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE6401A1A),
        border: Border.all(color: const Color(0x66FF8A80)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${errors.length} did not load',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          for (final String error in errors.take(4))
            Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
