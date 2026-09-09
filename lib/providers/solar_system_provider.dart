import 'package:flutter/foundation.dart';

import '../config/view_scale.dart';
import '../models/body_catalog.dart';
import '../models/celestial_body.dart';
import '../services/physics/simulation.dart';
import '../services/render/mesh_library.dart';

/// One entry on the time control.
class TimeSpeed {
  const TimeSpeed(this.label, this.daysPerSecond);

  final String label;

  /// Simulated days that pass per real second.
  final double daysPerSecond;
}

/// UI state for the solar system screen.
///
/// The simulation and the scene are the sources of truth for physics and
/// geometry; this holds what the interface needs on top of them.
class SolarSystemProvider extends ChangeNotifier {
  SolarSystemProvider({DateTime? start})
      : simulation = SolarSystemSimulation(start: start) {
    simulation.daysPerSecond = speeds[speedIndex].daysPerSecond;
  }

  final SolarSystemSimulation simulation;
  final MeshLibrary library = MeshLibrary();

  /// Load the models. The scene can be drawn as soon as this completes.
  Future<void> load() async {
    await library.loadAll();
    notifyListeners();
  }

  /// Time scales offered on the control, slowest first.
  static const List<TimeSpeed> speeds = <TimeSpeed>[
    TimeSpeed('Real time', 1.0 / 86400.0),
    TimeSpeed('1 min/s', 1.0 / 1440.0),
    TimeSpeed('1 hour/s', 1.0 / 24.0),
    TimeSpeed('1 day/s', 1.0),
    TimeSpeed('1 week/s', 7.0),
    TimeSpeed('1 month/s', 30.0),
    TimeSpeed('1 year/s', 365.25),
  ];

  int speedIndex = 3;
  bool get paused => simulation.paused;

  String? selectedKey;
  bool showOrbits = true;
  bool showMoons = true;
  ScaleMode scaleMode = ScaleMode.explore;

  /// Ticks once per frame so the clock display can rebuild on its own.
  final ValueNotifier<DateTime> clock =
      ValueNotifier<DateTime>(DateTime.now().toUtc());

  CelestialBody? get selected =>
      selectedKey == null ? null : BodyCatalog.byKey(selectedKey!);

  TimeSpeed get speed => speeds[speedIndex];

  /// Called once per rendered frame.
  void onFrame(double deltaSeconds) {
    simulation.advance(deltaSeconds);
    clock.value = simulation.time;
  }

  void setSpeedIndex(int index) {
    speedIndex = index.clamp(0, speeds.length - 1);
    simulation.daysPerSecond = speeds[speedIndex].daysPerSecond;
    notifyListeners();
  }

  void togglePaused() {
    simulation.paused = !simulation.paused;
    notifyListeners();
  }

  void resetToNow() {
    simulation.resetToNow();
    clock.value = simulation.time;
    notifyListeners();
  }

  void select(String? key) {
    selectedKey = key;
    notifyListeners();
  }

  void clearSelection() {
    selectedKey = null;
    notifyListeners();
  }

  void setOrbitsVisible(bool visible) {
    showOrbits = visible;
    notifyListeners();
  }

  void setMoonsVisible(bool visible) {
    showMoons = visible;
    notifyListeners();
  }

  void setScaleMode(ScaleMode mode) {
    scaleMode = mode;
    notifyListeners();
  }

  /// The scale currently in use.
  ViewScale get scale => ViewScale(mode: scaleMode);

  @override
  void dispose() {
    clock.dispose();
    library.dispose();
    super.dispose();
  }
}
