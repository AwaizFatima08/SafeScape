// End-to-end on a real device or emulator, with the real plugins (audio, TTS)
// and the real Firebase project: onboarding -> canvas -> routine -> sounds ->
// wait timer -> grown-ups area, then checks the cloud mirror in Firestore.
//
//   flutter test integration_test/app_flow_test.dart -d <device>

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('a full visit, mirrored to the cloud', (t) async {
    await app.main();
    // Slow phones (e.g. Galaxy A12) take a while to start Firebase and draw.
    final alias = find.byKey(const ValueKey('alias_field'));
    final hub = find.byKey(const ValueKey('hub_greeting'));
    for (var i = 0; i < 60 && alias.evaluate().isEmpty && hub.evaluate().isEmpty; i++) {
      await wait(t, 500);
    }
    await wait(t, 1000);

    // Onboarding (fresh install) or straight to the hub (re-run).
    if (alias.evaluate().isNotEmpty) {
      await t.enterText(find.byKey(const ValueKey('alias_field')), 'Tester');
      await t.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await wait(t, 1500); // let the keyboard close
      await tapKey(t, 'age_5-7');
      await tapKey(t, 'enter_button', settleMs: 3000);
    }
    expect(find.byKey(const ValueKey('hub_greeting')), findsOneWidget);

    // Calming Canvas: 12 s of real two-finger play so a session is logged.
    await tapKey(t, 'card_canvas');
    final canvas = find.byKey(const ValueKey('flow_canvas'));
    final c = t.getCenter(canvas);
    final end = DateTime.now().add(const Duration(seconds: 12));
    var k = 0;
    while (DateTime.now().isBefore(end)) {
      final g1 = await t.startGesture(c + Offset(-60.0 + (k % 5) * 10, 0), pointer: 1);
      final g2 = await t.startGesture(c + Offset(40, 80.0 - (k % 7) * 8), pointer: 2);
      for (var i = 0; i < 12; i++) {
        await g1.moveBy(Offset(8, (i.isEven ? -5 : 5)));
        await g2.moveBy(const Offset(-6, -4));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g1.up();
      await g2.up();
      k++;
    }
    await tapKey(t, 'palette_blue'); // used briefly: the session keeps the longest-used palette
    await tapKey(t, 'home');

    // A routine: finish every step.
    await tapKey(t, 'card_routines');
    await tapKey(t, find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('routine_'))
        .evaluate()
        .map((e) => '${(e.widget.key as ValueKey).value}')
        .first);
    for (var i = 0; i < 6; i++) {
      final step = find.byKey(ValueKey('step_$i'));
      if (step.evaluate().isEmpty) break;
      await tapKey(t, 'step_$i', settleMs: 1500);
    }
    await wait(t, 2000);
    expect(find.byKey(const ValueKey('celebration')), findsOneWidget);
    await tapKey(t, 'celebrate_home');

    // Sounds for 11 s.
    await tapKey(t, 'card_sounds');
    await tapKey(t, 'sound_rain');
    await wait(t, 11000);
    await tapKey(t, 'sound_rain');
    await tapKey(t, 'home');

    // Grown-ups area.
    await tapKey(t, 'parent_lock');
    final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!)}'.split('')) {
      await t.tap(find.byKey(ValueKey('gate_$ch')));
      await t.pump();
    }
    await wait(t, 1500);
    expect(find.text('Calm & Focus Horizon'), findsOneWidget);
    // What the dashboard summarises: the sessions the app recorded.
    final store = ProviderScope.containerOf(t.element(find.byType(SafeScapeApp))).read(storeProvider);
    final recorded = store.data.sessions;
    expect(recorded.any((x) => x.mode == 'flow_canvas' && x.palette == 'lavender' && x.durationSeconds >= 10), isTrue,
        reason: 'the palette used longest is recorded');
    expect(recorded.any((x) => x.mode == 'sounds' && x.sound == 'rain' && x.durationSeconds >= 10), isTrue);
    expect(recorded.any((x) => x.mode == 'routine' && x.stepsDone == x.stepsTotal && x.stepsTotal > 0), isTrue);
    for (final tab in ['tab_sensory', 'tab_routines', 'tab_family', 'tab_account']) {
      await tapKey(t, tab);
    }

    // The cloud mirror: anonymous account, owner-only data under users/{uid}.
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull, reason: 'silent anonymous sign-in');
    await wait(t, 4000);
    final kids = await FirebaseFirestore.instance.collection('users/${user!.uid}/children').get();
    expect(kids.docs, isNotEmpty);
    final sessions = await kids.docs.first.reference.collection('sessions').get();
    final modes = sessions.docs.map((d) => d.data()['mode_used']).toSet();
    expect(modes, containsAll(['flow_canvas', 'routine', 'sounds']));
    // Rules: another user's data is unreachable.
    await expectLater(
      FirebaseFirestore.instance.collection('users/someone-else/children').get(const GetOptions(source: Source.server)),
      throwsA(isA<FirebaseException>()),
    );
  });
}
