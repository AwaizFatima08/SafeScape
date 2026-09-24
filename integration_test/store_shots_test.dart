// Drives the app through its main screens for Play Store screenshots.
// scripts/take_screenshots.sh watches for "SHOT:<name>" lines and captures the
// emulator screen with adb while the test holds still.
//
// WARNING: this wipes the app's data on the device first.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safescape/app.dart';
import 'package:safescape/main.dart' as app;
import 'package:safescape/models/models.dart';
import 'package:safescape/state/providers.dart';

Future<void> wait(WidgetTester t, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 33));
  }
}

Future<void> shot(WidgetTester t, String name) async {
  await wait(t, 1200);
  // ignore: avoid_print
  print('SHOT:$name');
  await wait(t, 5000);
}

Future<void> tapKey(WidgetTester t, String key, {int settleMs = 1200}) async {
  final f = find.byKey(ValueKey(key));
  await wait(t, 300);
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 250,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);
  }
  // Only scroll when the target is off-screen: ensureVisible also moves
  // horizontal ancestors (e.g. a TabBarView) and can switch tabs.
  final r = t.getRect(f);
  final screen = Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  if (!screen.contains(r.topLeft) || !screen.contains(r.bottomRight - const Offset(1, 1))) {
    await t.ensureVisible(f);
  }
  await wait(t, 400);
  await t.tap(f);
  await wait(t, settleMs);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (t) async {
    await app.main();
    await wait(t, 2500);
    final container = ProviderScope.containerOf(t.element(find.byType(SafeScapeApp)));
    final store = container.read(storeProvider);
    store.updateSettings((s) => s.cloudBackup = false);
    await store.wipe();
    store.updateSettings((s) => s.cloudBackup = false);
    await wait(t, 1500);

    await t.enterText(find.byKey(const ValueKey('alias_field')), 'Maya');
    await t.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await wait(t, 1500); // let the keyboard close
    await wait(t, 800);
    await shot(t, '01_welcome');
    await tapKey(t, 'enter_button', settleMs: 2500);
    store.updateSettings((s) => s.cloudBackup = false);

    // A week of believable history for the progress screen.
    final child = store.activeChild!;
    final now = DateTime.now();
    const daily = [12, 8, 15, 6, 18, 10, 14];
    for (var d = 0; d < 7; d++) {
      final day = now.subtract(Duration(days: 6 - d));
      store.logSession(SensorySession(id: newId('s'), childId: child.id, mode: 'flow_canvas',
          start: day, durationSeconds: daily[d] * 40, palette: d.isEven ? 'lavender' : 'mint', touchRhythm: 'slow_rhythmic'));
      store.logSession(SensorySession(id: newId('s'), childId: child.id, mode: 'sounds',
          start: day, durationSeconds: daily[d] * 20, sound: d % 3 == 0 ? 'rain' : 'ocean'));
      store.logSession(SensorySession(id: newId('s'), childId: child.id, mode: 'routine', start: day,
          durationSeconds: 600, routineId: 'x', routineTitle: 'Bedtime Routine', stepsDone: d == 2 ? 3 : 5, stepsTotal: 5));
    }
    await shot(t, '02_hub');

    await tapKey(t, 'card_canvas');
    final c = t.getCenter(find.byKey(const ValueKey('flow_canvas')));
    for (var k = 0; k < 6; k++) {
      final g = await t.startGesture(c + Offset(-120.0 + k * 40, -260.0 + k * 30), pointer: 10 + k);
      for (var i = 0; i < 25; i++) {
        await g.moveBy(Offset(9, (i < 12 ? 7 : -7)));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
    }
    // ignore: avoid_print
    print('SHOT:03_canvas');
    for (var i = 0; i < 90; i++) {
      final g = await t.startGesture(c + Offset(-100.0 + (i % 10) * 22, 120.0 + (i % 5) * 20), pointer: 40 + i);
      await g.moveBy(const Offset(12, -8));
      await t.pump(const Duration(milliseconds: 30));
      await g.up();
      await t.pump(const Duration(milliseconds: 30));
    }
    await tapKey(t, 'home');

    await tapKey(t, 'card_routines');
    await shot(t, '04_routines');
    final doctor = store.routinesFor(child.id).firstWhere((r) => r.title == 'Visiting the Doctor');
    await tapKey(t, 'routine_${doctor.id}');
    await tapKey(t, 'step_0', settleMs: 1500);
    await tapKey(t, 'step_1', settleMs: 400);
    await wait(t, 300);
    // ignore: avoid_print
    print('SHOT:05_routine');
    await wait(t, 5000);
    await tapKey(t, 'home');

    await tapKey(t, 'card_sounds');
    await tapKey(t, 'sound_rain');
    await shot(t, '06_sounds');
    await tapKey(t, 'home');

    await tapKey(t, 'card_wait');
    await tapKey(t, 'wait_5');
    await tapKey(t, 'then_park');
    await tapKey(t, 'wait_start');
    await wait(t, 8000);
    await shot(t, '07_wait');
    await tapKey(t, 'home');

    await tapKey(t, 'parent_lock');
    final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!)}'.split('')) {
      await t.tap(find.byKey(ValueKey('gate_$ch')));
      await t.pump();
    }
    await shot(t, '08_progress');
    await tapKey(t, 'tab_sensory');
    await shot(t, '09_sensory');
    await tapKey(t, 'tab_routines');
    await tapKey(t, 'edit_${doctor.id}');
    await shot(t, '10_editor');
  });
}
