import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safescape/models/models.dart';

import 'helpers.dart';

/// Screens animate forever (Sammy, the canvas), so never pumpAndSettle.
Future<void> settle(WidgetTester t, [int ms = 1200]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.625;
  addTearDown(t.view.reset);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.pump(const Duration(milliseconds: 300));
  if (f.evaluate().isEmpty) {
    // Lazily built list item: scroll the main vertical list until it exists.
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
  // Let any running scroll (e.g. a text field revealing itself) finish:
  // scrollables ignore taps mid-scroll.
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(f);
  await settle(t);
}

Future<void> passGate(WidgetTester t) async {
  await tapKey(t, 'parent_lock');
  final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  final answer = int.parse(m[1]!) * int.parse(m[2]!);
  for (final ch in '$answer'.split('')) {
    await t.tap(find.byKey(ValueKey('gate_$ch')));
    await t.pump();
  }
  await settle(t);
}

void main() {
  testWidgets('first launch: onboarding with no sign-up leads to the hub', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    await t.pumpWidget(env!.app());
    await settle(t);
    expect(find.text('Welcome to SafeScape'), findsOneWidget);
    expect(find.textContaining('No sign-up needed'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('alias_field')), 'Sunny');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await tapKey(t, 'age_8-10');
    await tapKey(t, 'soft_lighting');
    await tapKey(t, 'cloud_backup');
    await tapKey(t, 'enter_button');
    expect(find.text('Hi, Sunny!'), findsOneWidget);
    final c = env.store.activeChild!;
    expect(c.ageGroup, '8-10');
    expect(c.sensory.softLighting, isTrue);
    expect(c.sensory.lowMotion, isFalse);
    expect(env.store.settings.cloudBackup, isFalse);
    for (final k in ['card_canvas', 'card_routines', 'card_sounds', 'card_wait']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget);
    }
  });

  testWidgets('the Enter button works without typing anything', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    await t.pumpWidget(env!.app());
    await settle(t);
    await tapKey(t, 'enter_button');
    expect(find.text('Hi, Friend!'), findsOneWidget);
  });

  testWidgets('parent gate: a wrong answer gives a new question, the right one opens the dashboard', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'Kai', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'parent_lock');
    for (final k in ['1', '1']) {
      await t.tap(find.byKey(ValueKey('gate_$k')));
      await t.pump();
    }
    // Every question's answer has two digits (3..9 x 6..9 >= 18), so "11" is wrong.
    expect(find.text('Not quite. Here is a new one.'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await settle(t);
    await passGate(t);
    expect(find.text('Grown-ups'), findsOneWidget);
    expect(find.text('Calm & Focus Horizon'), findsOneWidget);
    for (final tab in ['tab_sensory', 'tab_routines', 'tab_family', 'tab_account']) {
      await tapKey(t, tab);
      expect(t.takeException(), isNull, reason: tab);
    }
    expect(find.text('Cloud backup is not available on this device.'), findsOneWidget);
  });

  testWidgets('routine: errorless steps, star burst, chime and celebration', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final child = env!.store.addChild(alias: 'Mo', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_routines');
    final r = env.store.routinesFor(child.id).firstWhere((r) => r.title == 'Visiting the Doctor');
    await tapKey(t, 'routine_${r.id}');
    expect(find.text('0/5 Done'), findsOneWidget);
    expect(find.byKey(const ValueKey('first_then')), findsOneWidget);
    expect(env.speech.spoken.last, contains('First, Put on shoes'));

    // Tapping a later card only reads it (with its story); nothing is "wrong".
    await tapKey(t, 'step_3');
    expect(r.steps[3].isCompleted, isFalse);
    expect(env.speech.spoken.last, contains('listens to my heart'));
    expect(find.text('0/5 Done'), findsOneWidget);

    for (var i = 0; i < 5; i++) {
      await tapKey(t, 'step_$i');
    }
    expect(r.isFinished, isTrue);
    expect(env.sound.played.where((p) => p == 'sfx:step').length, 4);
    expect(env.sound.played.last, 'sfx:done');
    await settle(t, 1500);
    expect(find.byKey(const ValueKey('celebration')), findsOneWidget);
    expect(find.text('Great job, Mo!'), findsOneWidget);
    await tapKey(t, 'celebrate_again');
    expect(r.doneCount, 0);
    expect(find.text('0/5 Done'), findsOneWidget);
    final runs = env.store.sessionsFor(child.id).where((s) => s.mode == 'routine').toList();
    expect(runs.single.stepsDone, 5);
  });

  testWidgets('global mute works from any screen', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'mute');
    expect(env.store.settings.audioMuted, isTrue);
    await tapKey(t, 'card_sounds');
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    await tapKey(t, 'mute');
    expect(env.store.settings.audioMuted, isFalse);
  });

  testWidgets('soothing sounds use the filtered variant for the child', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final c = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_sounds');
    await tapKey(t, 'sound_rain');
    expect(env.sound.played.last, 'loop:rain:4k', reason: 'Mute High Pitch is on by default');
    expect(env.sound.currentLoop, 'rain');
    await tapKey(t, 'sound_rain');
    expect(env.sound.currentLoop, isNull);
    c.sensory.audioCutoffHz = 2500;
    await tapKey(t, 'sound_ocean');
    expect(env.sound.played.last, 'loop:ocean:2k5');
    await tapKey(t, 'fade_20');
    await tapKey(t, 'home');
    expect(env.sound.currentLoop, isNull, reason: 'leaving the screen stops the sound');
  });

  testWidgets('small phone (Galaxy A12 size): the home button never scrolls away', (t) async {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 2.0;
    addTearDown(t.view.reset);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    for (final card in ['card_sounds', 'card_wait']) {
      await tapKey(t, card);
      await t.drag(find.byType(ListView).first, const Offset(0, -2000));
      await settle(t, 600);
      final home = find.byKey(const ValueKey('home'));
      expect(home.hitTestable(), findsOneWidget, reason: card);
      await t.tap(home);
      await settle(t);
      expect(find.byKey(const ValueKey('hub_greeting')), findsOneWidget);
    }
  });

  testWidgets('Galaxy A12 with large text (340 dp, x1.3): nothing is truncated', (t) async {
    t.view.physicalSize = const Size(720, 1600);
    t.view.devicePixelRatio = 720 / 340;
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final env = await t.runAsync(() => makeEnv());
    final child = env!.store.addChild(alias: 'Maya', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);

    void noTruncation(String where) {
      for (final p in t.allRenderObjects.whereType<RenderParagraph>()) {
        expect(p.didExceedMaxLines, isFalse, reason: '$where: "${p.text.toPlainText()}" is cut off');
      }
      expect(t.takeException(), isNull, reason: where);
    }

    noTruncation('hub');
    await tapKey(t, 'card_routines');
    noTruncation('routines');
    final doctor = env.store.routinesFor(child.id).firstWhere((r) => r.title == 'Visiting the Doctor');
    await tapKey(t, 'routine_${doctor.id}');
    noTruncation('routine player');
    await tapKey(t, 'home');
    await tapKey(t, 'card_canvas');
    noTruncation('canvas');
    for (final p in ['lavender', 'mint', 'sand', 'blue']) {
      expect(t.getSize(find.byKey(ValueKey('palette_$p'))).width, greaterThanOrEqualTo(72), reason: p);
    }
    await tapKey(t, 'home');
    await tapKey(t, 'card_sounds');
    noTruncation('sounds');
    await tapKey(t, 'home');
    await tapKey(t, 'card_wait');
    noTruncation('wait timer');
  });

  testWidgets('flow canvas: multi-touch, palettes and reset', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final c = env!.store.addChild(alias: 'A', ageGroup: '2-4');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_canvas');
    expect(env.sound.played.last, 'loop:hum:4k');
    final canvas = find.byKey(const ValueKey('flow_canvas'));
    final center = t.getCenter(canvas);
    final g1 = await t.startGesture(center, pointer: 1);
    final g2 = await t.startGesture(center + const Offset(80, 120), pointer: 2);
    for (var i = 0; i < 30; i++) {
      await g1.moveBy(const Offset(6, -4));
      await g2.moveBy(const Offset(-5, 3));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    expect(env.sound.played, contains('sfx:tap'));
    await tapKey(t, 'palette_mint');
    expect(c.sensory.palette, 'mint');
    await tapKey(t, 'canvas_reset');
    await tapKey(t, 'canvas_sound');
    expect(c.sensory.canvasSound, isFalse);
    expect(env.sound.currentLoop, isNull);
    // The guide alternates: 4 s "Breathe in", 6 s "Breathe out".
    final seen = <String>{};
    for (var i = 0; i < 110; i++) {
      await t.pump(const Duration(milliseconds: 100));
      if (find.text('Breathe in').evaluate().isNotEmpty) seen.add('in');
      if (find.text('Breathe out').evaluate().isNotEmpty) seen.add('out');
    }
    expect(seen, {'in', 'out'});
    await tapKey(t, 'home');
    expect(find.text('Hi, A!'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('wait timer ends with one soft note and the next activity', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final c = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_wait');
    await tapKey(t, 'wait_1');
    await tapKey(t, 'then_park');
    await tapKey(t, 'wait_start');
    await t.pump(const Duration(seconds: 30));
    expect(find.byKey(const ValueKey('wait_stop')), findsOneWidget);
    await t.pump(const Duration(seconds: 31));
    await settle(t);
    expect(find.byKey(const ValueKey('wait_done')), findsOneWidget);
    expect(find.text('Time for park!'), findsOneWidget);
    expect(env.sound.played.last, 'sfx:wait_end');
    expect(env.store.sessionsFor(c.id).where((s) => s.mode == 'wait_timer'), isNotEmpty);
  });

  testWidgets('routine builder: new routine with a step', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final c = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    final before = env.store.routinesFor(c.id).length;
    await t.pumpWidget(env.app());
    await settle(t);
    await passGate(t);
    await tapKey(t, 'tab_routines');
    await tapKey(t, 'add_routine');
    // Tap the sheet item directly: auto-scrolling here can move the tab view behind.
    await t.tap(find.byKey(const ValueKey('new_blank')));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
      }
    await t.enterText(find.byKey(const ValueKey('routine_title')), 'Swimming');
    await tapKey(t, 'add_step');
    await t.enterText(find.byKey(const ValueKey('step_title')), 'Put on goggles');
    await t.enterText(find.byKey(const ValueKey('step_story')), 'The water might feel cold at first.');
    await tapKey(t, 'step_icon');
    await tapKey(t, 'icon_swim');
    await tapKey(t, 'step_done');
    expect(find.text('1. Put on goggles'), findsOneWidget);
    await tapKey(t, 'save_routine');
    final routines = env.store.routinesFor(c.id);
    expect(routines.length, before + 1);
    final r = routines.firstWhere((r) => r.title == 'Swimming');
    expect(r.steps.single.iconKey, 'swim');
    expect(r.steps.single.story, contains('cold'));
  });

  testWidgets('sensory settings change the child profile', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final c = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await passGate(t);
    await tapKey(t, 'tab_sensory');
    await tapKey(t, 'set_low_motion');
    expect(c.sensory.lowMotion, isTrue);
    await tapKey(t, 'set_mute_high');
    expect(c.sensory.muteHighPitch, isFalse);
    expect(c.sensory.audioVariant, '6k');
    await t.ensureVisible(find.text('2.5 kHz'));
    await t.tap(find.text('2.5 kHz'));
    await settle(t);
    expect(c.sensory.audioVariant, '2k5');
  });

  testWidgets('progress shows logged activity', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final c = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    env.store.logSession(SensorySession(
        id: newId('s'), childId: c.id, mode: 'flow_canvas', start: DateTime.now(), durationSeconds: 600, palette: 'mint'));
    env.store.logSession(SensorySession(
        id: newId('s'), childId: c.id, mode: 'sounds', start: DateTime.now(), durationSeconds: 300, sound: 'rain'));
    await t.pumpWidget(env.app());
    await settle(t);
    await passGate(t);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('Flow Canvas (Mint)'), findsOneWidget);
    expect(find.text('Soft Rain'), findsOneWidget);
  });

  testWidgets('several children: add and switch', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'First', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await passGate(t);
    await tapKey(t, 'tab_family');
    await tapKey(t, 'add_child');
    expect(find.text('Add a child'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('alias_field')), 'Second');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await tapKey(t, 'enter_button');
    expect(env.store.data.children.length, 2);
    expect(env.store.activeChild!.alias, 'Second');
    expect(find.byKey(const ValueKey('child_switcher')), findsOneWidget);
  });
}
