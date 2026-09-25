// First launch with no network (run with Wi-Fi and mobile data off, see
// scripts/offline_check.sh): everything must work, nothing may hang, and the
// backup must say it's waiting for a connection.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:safescape/app.dart';
import 'package:safescape/main.dart' as app;
import 'package:safescape/state/providers.dart';

Future<void> wait(WidgetTester t, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tapKey(WidgetTester t, String key, {int settleMs = 1200}) async {
  final f = find.byKey(ValueKey(key));
  await wait(t, 300);
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(f, 250,
        scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);
  }
  final lists = find.ancestor(of: f, matching: find.byType(Scrollable));
  final screen = lists.evaluate().isNotEmpty
      ? t.getRect(lists.first)
      : Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  final r = t.getRect(f);
  if (!screen.contains(r.topLeft) || !screen.contains(r.bottomRight - const Offset(1, 1))) {
    await t.ensureVisible(f);
  }
  await wait(t, 400);
  await t.tap(f);
  await wait(t, settleMs);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch offline: everything works', (t) async {
    final started = DateTime.now();
    await app.main();
    final alias = find.byKey(const ValueKey('alias_field'));
    final hub = find.byKey(const ValueKey('hub_greeting'));
    for (var i = 0; i < 60 && alias.evaluate().isEmpty && hub.evaluate().isEmpty; i++) {
      await wait(t, 500);
    }
    // ignore: avoid_print
    print('OFFLINE start-up took ${DateTime.now().difference(started).inMilliseconds} ms');
    final store = ProviderScope.containerOf(t.element(find.byType(SafeScapeApp))).read(storeProvider);
    if (hub.evaluate().isNotEmpty) {
      await store.wipe();
      await wait(t, 1500);
    }
    await t.enterText(alias, 'Offline');
    await t.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(t, 1500);
    final tapped = DateTime.now();
    await tapKey(t, 'enter_button', settleMs: 500);
    for (var i = 0; i < 40 && hub.evaluate().isEmpty; i++) {
      await wait(t, 250);
    }
    // ignore: avoid_print
    print('OFFLINE enter -> hub took ${DateTime.now().difference(tapped).inMilliseconds} ms');
    expect(hub, findsOneWidget, reason: 'onboarding must not wait for the network');

    // A routine step, the canvas and a sound, all offline.
    await tapKey(t, 'card_routines');
    final r = store.routinesFor(store.activeChild!.id).first;
    await tapKey(t, 'routine_${r.id}');
    await tapKey(t, 'step_0');
    expect(r.steps.first.isCompleted, isTrue);
    await tapKey(t, 'home');
    await tapKey(t, 'card_canvas');
    final c = t.getCenter(find.byKey(const ValueKey('flow_canvas')));
    final g = await t.startGesture(c);
    for (var i = 0; i < 30; i++) {
      await g.moveBy(const Offset(6, 4));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tapKey(t, 'home');
    await tapKey(t, 'card_sounds');
    await tapKey(t, 'sound_ocean');
    await wait(t, 2000);
    await tapKey(t, 'sound_ocean');
    await tapKey(t, 'home');

    // The backup says it's waiting, and nothing is stuck.
    await tapKey(t, 'parent_lock');
    final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!)}'.split('')) {
      await t.tap(find.byKey(ValueKey('gate_$ch')));
      await t.pump();
    }
    await wait(t, 1500);
    await tapKey(t, 'tab_account');
    expect(find.textContaining('Waiting for an internet connection'), findsOneWidget);
    await store.flush();
    expect(store.onboarded, isTrue);
  });
}
