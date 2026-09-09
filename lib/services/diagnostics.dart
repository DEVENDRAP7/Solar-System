import 'dart:io';

import 'package:flutter/foundation.dart';

/// Collects errors that would otherwise be invisible on a device.
///
/// The renderer starts inside an unawaited future in the viewer package, so a
/// failure there never reaches the widget tree: the app just sits on its
/// loading screen. These handlers catch those errors so the app can show what
/// actually went wrong instead of nothing at all.
class AppDiagnostics {
  const AppDiagnostics._();

  static final ValueNotifier<List<String>> messages =
      ValueNotifier<List<String>>(<String>[]);

  /// Short description of the device, useful when reporting a problem.
  static String get platform {
    if (Platform.isAndroid || Platform.isIOS) {
      return '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    }
    return Platform.operatingSystem;
  }

  static void record(Object error, [StackTrace? stack]) {
    final String text = error.toString();
    final List<String> next = List<String>.from(messages.value);

    // The same failure often arrives repeatedly from the render loop.
    if (next.contains(text)) {
      return;
    }
    next.add(text);
    messages.value = next;

    if (kDebugMode) {
      debugPrint('Diagnostics: $text');
      if (stack != null) {
        debugPrintStack(stackTrace: stack);
      }
    }
  }

  /// Route framework and platform errors here as well as to the console.
  static void install() {
    final FlutterExceptionHandler? existing = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      record(details.exception, details.stack);
      existing?.call(details);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      record(error, stack);
      return true;
    };
  }
}
