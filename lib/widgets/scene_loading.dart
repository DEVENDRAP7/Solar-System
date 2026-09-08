import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Loading screen for the 3D scene.
///
/// It reports which step is running. If the text stops changing, the step it
/// names is the one that is stuck — which is the difference between a slow
/// load and a broken one.
class SceneLoading extends StatelessWidget {
  const SceneLoading({required this.status, super.key});

  final ValueListenable<String> status;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppTheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 22),
            ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (BuildContext context, String value, Widget? _) {
                return Text(value, style: text.titleMedium);
              },
            ),
          ],
        ),
      ),
    );
  }
}
