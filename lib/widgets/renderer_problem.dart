import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/diagnostics.dart';

/// Shown when the 3D renderer never starts.
///
/// The renderer is a native OpenGL surface set up by the viewer package before
/// any of our code runs, so when it fails there is nothing on screen to say so.
/// This reports what was caught and offers the other surface mode, which is the
/// setting most likely to differ between devices.
class RendererProblem extends StatelessWidget {
  const RendererProblem({
    required this.usingSurfaceProducer,
    required this.onRetryOtherMode,
    super.key,
  });

  final bool usingSurfaceProducer;
  final VoidCallback onRetryOtherMode;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppTheme.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('The 3D renderer did not start', style: text.titleLarge),
                const SizedBox(height: 10),
                Text(
                  'The scene runs on a native OpenGL surface. It has not come '
                  'up on this device.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 18),
                _Row(
                  label: 'Device',
                  value: AppDiagnostics.platform,
                ),
                _Row(
                  label: 'Surface mode',
                  value: usingSurfaceProducer ? 'SurfaceProducer' : 'Legacy',
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<List<String>>(
                  valueListenable: AppDiagnostics.messages,
                  builder: (BuildContext context, List<String> errors, Widget? _) {
                    if (errors.isEmpty) {
                      return Text(
                        'No error was reported, which usually means the native '
                        'call never returned.',
                        style: text.bodyMedium,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('REPORTED', style: text.labelSmall),
                        const SizedBox(height: 6),
                        for (final String error in errors.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(error, style: text.bodyMedium),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                FilledButton.tonal(
                  onPressed: onRetryOtherMode,
                  child: Text(
                    usingSurfaceProducer
                        ? 'Retry with legacy surface'
                        : 'Retry with SurfaceProducer',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label.toUpperCase(), style: text.labelSmall),
          ),
          Expanded(child: SelectableText(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
