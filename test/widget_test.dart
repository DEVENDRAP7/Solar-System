import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_system_app/config/theme.dart';
import 'package:solar_system_app/models/body_catalog.dart';
import 'package:solar_system_app/providers/solar_system_provider.dart';
import 'package:solar_system_app/widgets/body_info_sheet.dart';
import 'package:solar_system_app/widgets/body_picker.dart';
import 'package:solar_system_app/widgets/time_controls.dart';

/// The 3D screen needs a GL context, so these cover the interface layered on
/// top of it. The scene itself is exercised on a device.
Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  group('BodyInfoSheet', () {
    testWidgets('shows the body and its facts', (WidgetTester tester) async {
      await tester.pumpWidget(wrap(BodyInfoSheet(
        body: BodyCatalog.jupiter,
        onClose: () {},
      )));

      expect(find.text('Jupiter'), findsOneWidget);
      expect(find.text('GAS GIANT'), findsOneWidget);
      expect(find.text('69911 km'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
    });

    test('marks retrograde rotation', () {
      expect(BodyInfoSheet.describeRotation(-5832.5), contains('retrograde'));
      expect(BodyInfoSheet.describeRotation(23.9), isNot(contains('retro')));
      expect(BodyInfoSheet.describeRotation(23.9), '23.9 hours');
      expect(BodyInfoSheet.describeRotation(655.72), '27.3 days');
    });

    test('formats orbital periods by magnitude', () {
      expect(BodyInfoSheet.describePeriod(87.969), '88.0 days');
      expect(BodyInfoSheet.describePeriod(4332.589), '11.9 years');
      expect(BodyInfoSheet.describePeriod(null), '—');
    });

    testWidgets('close button fires', (WidgetTester tester) async {
      int closed = 0;
      await tester.pumpWidget(wrap(BodyInfoSheet(
        body: BodyCatalog.earth,
        onClose: () => closed++,
      )));

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, 1);
    });
  });

  group('BodyPicker', () {
    testWidgets('lists every body and reports taps', (WidgetTester tester) async {
      String? picked;
      await tester.pumpWidget(wrap(BodyPicker(
        selectedKey: null,
        onSelected: (String key) => picked = key,
      )));

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mercury'), findsOneWidget);

      await tester.tap(find.text('Mercury'));
      expect(picked, 'mercury');
    });
  });

  group('TimeControls', () {
    test('formats the simulated date', () {
      expect(
        TimeControls.formatDate(DateTime.utc(2026, 9, 8, 19, 5)),
        '8 Sep 2026  19:05 UTC',
      );
    });

    testWidgets('pause and reset fire', (WidgetTester tester) async {
      int paused = 0;
      int reset = 0;
      final ValueNotifier<DateTime> clock =
          ValueNotifier<DateTime>(DateTime.utc(2026, 1, 1));
      addTearDown(clock.dispose);

      await tester.pumpWidget(wrap(TimeControls(
        speedIndex: 3,
        paused: false,
        clock: clock,
        onSpeedChanged: (int _) {},
        onTogglePaused: () => paused++,
        onResetToNow: () => reset++,
      )));

      expect(find.text('1 day/s'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.tap(find.byIcon(Icons.restore_rounded));
      expect(paused, 1);
      expect(reset, 1);
    });
  });

  group('Time speeds', () {
    test('are ordered slowest to fastest', () {
      double previous = 0.0;
      for (final TimeSpeed speed in SolarSystemProvider.speeds) {
        expect(speed.daysPerSecond, greaterThan(previous), reason: speed.label);
        previous = speed.daysPerSecond;
      }
    });

    test('real time means one day per day', () {
      expect(SolarSystemProvider.speeds.first.daysPerSecond * 86400.0,
          closeTo(1.0, 1e-9));
    });
  });
}
