import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/theme.dart';
import 'screens/solar_system_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SolarSystemApp());
}

/// Application shell.
class SolarSystemApp extends StatelessWidget {
  const SolarSystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solar System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SolarSystemScreen(),
    );
  }
}
