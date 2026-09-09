import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;

import '../config/theme.dart';
import '../models/celestial_body.dart';
import '../providers/solar_system_provider.dart';
import '../widgets/body_info_sheet.dart';
import '../widgets/body_picker.dart';
import '../widgets/display_options.dart';
import '../widgets/renderer_problem.dart';
import '../widgets/scene_loading.dart';
import '../widgets/time_controls.dart';

/// The main screen: the 3D scene with its controls layered over it.
class SolarSystemScreen extends StatefulWidget {
  const SolarSystemScreen({super.key});

  @override
  State<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends State<SolarSystemScreen> {
  late SolarSystemProvider _provider;
  late three.ThreeJS _viewer;

  /// Which Android surface path the renderer is using. The viewer defaults to
  /// SurfaceProducer; the underlying plugin defaults to the legacy path, and
  /// devices differ on which one works, so both are reachable.
  bool _useSurfaceProducer = true;

  /// Set when the renderer fails to call into our setup in reasonable time.
  bool _rendererStalled = false;

  Timer? _watchdog;

  /// How long to wait for the native renderer before reporting a problem.
  static const Duration _rendererTimeout = Duration(seconds: 20);

  /// Rebuilding the viewer needs a fresh key so Flutter discards the old
  /// native texture widget rather than reusing it.
  int _viewerGeneration = 0;

  /// Where the current pointer gesture started, so a drag that orbits the
  /// camera is not mistaken for a tap that selects a body.
  Offset? _pointerDownAt;

  static const double _tapSlop = 12.0;

  @override
  void initState() {
    super.initState();
    _startViewer();
  }

  void _startViewer() {
    _provider = SolarSystemProvider();
    _viewer = three.ThreeJS(
      settings: three.Settings(useSurfaceProducer: _useSurfaceProducer),
      onSetupComplete: () => setState(() {}),
      setup: _setupScene,
      loadingWidget: SceneLoading(status: _provider.scene.status),
    );

    _watchdog?.cancel();
    _watchdog = Timer(_rendererTimeout, () {
      if (!mounted || _provider.scene.setupStarted.value) {
        return;
      }
      setState(() => _rendererStalled = true);
    });
  }

  /// Tear down and start again on the other surface mode.
  void _retryOtherMode() {
    final SolarSystemProvider old = _provider;
    setState(() {
      _useSurfaceProducer = !_useSurfaceProducer;
      _rendererStalled = false;
      _viewerGeneration++;
      _viewer.dispose();
      _startViewer();
    });
    old.dispose();
  }

  /// The viewer only reveals the scene once this returns, and it does not
  /// catch anything thrown here — an escaping error would leave the app on its
  /// loading spinner forever. So nothing is allowed to escape.
  Future<void> _setupScene() async {
    try {
      await _provider.scene.setup(_viewer);
    } catch (error, stack) {
      _provider.scene.errors.add('Scene setup failed: $error');
      debugPrintStack(stackTrace: stack, label: '$error');
    }
    try {
      _viewer.addAnimationEvent(_provider.onFrame);
    } catch (error) {
      _provider.scene.errors.add('Animation loop failed: $error');
    }

    // Deliberately not awaited: the scene is shown as soon as this method
    // returns, and the planets arrive into it as they finish loading.
    unawaited(_loadRemaining());
  }

  Future<void> _loadRemaining() async {
    try {
      await _provider.scene.loadRemainingBodies();
    } catch (error) {
      _provider.scene.errors.add('Loading bodies failed: $error');
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
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
    if (_rendererStalled) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: RendererProblem(
          usingSurfaceProducer: _useSurfaceProducer,
          onRetryOtherMode: _retryOtherMode,
        ),
      );
    }

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
                      key: ValueKey<int>(_viewerGeneration),
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (PointerDownEvent event) =>
                          _pointerDownAt = event.localPosition,
                      onPointerUp: (PointerUpEvent event) =>
                          _handlePointerUp(event, size),
                      child: _viewer.build(),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: MediaQuery.of(context).padding.top + 12,
                    child: _LoadingChip(
                      loading: _provider.scene.loadingBodies,
                      status: _provider.scene.status,
                    ),
                  ),
                  if (_provider.scene.errors.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 64,
                      top: MediaQuery.of(context).padding.top + 48,
                      child: _SceneErrors(errors: _provider.scene.errors),
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


/// Shows what failed to load, so a partly built scene explains itself.
class _SceneErrors extends StatelessWidget {
  const _SceneErrors({required this.errors});

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


/// Small badge showing bodies still streaming into the scene.
class _LoadingChip extends StatelessWidget {
  const _LoadingChip({required this.loading, required this.status});

  final ValueListenable<bool> loading;
  final ValueListenable<String> status;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: loading,
      builder: (BuildContext context, bool busy, Widget? _) {
        if (!busy) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.panel,
            border: Border.all(color: AppTheme.panelBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(width: 9),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (BuildContext context, String value, Widget? _) {
                  return Text(
                    value,
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
