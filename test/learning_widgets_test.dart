// v1.2 screens: Learn with Sammy, the four practices, Picture Stories and the
// grown-ups' story editor — including the Galaxy A12 large-text check.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

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

Future<void> tapKey(WidgetTester t, String key, {int ms = 1200}) async {
  final f = find.byKey(ValueKey(key));
  await t.pump(const Duration(milliseconds: 300));
  if (f.evaluate().isEmpty) {
    await t.scrollUntilVisible(
      f,
      250,
      scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last,
    );
  }
  final lists = find.ancestor(of: f, matching: find.byType(Scrollable));
  final r = t.getRect(f);
  final area = lists.evaluate().isNotEmpty
      ? t.getRect(lists.first)
      : Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  if (!area.contains(r.topLeft) || !area.contains(r.bottomRight - const Offset(1, 1))) await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 400));
  await t.tap(f);
  await settle(t, ms);
}

Future<void> passGate(WidgetTester t) async {
  await tapKey(t, 'parent_lock');
  final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!)}'.split('')) {
    await t.tap(find.byKey(ValueKey('gate_$ch')));
    await t.pump();
  }
  await settle(t);
}

/// Taps Next until the practice page (the last page) is showing.
Future<void> toPractice(WidgetTester t, int cards) async {
  for (var i = 0; i < cards; i++) {
    await tapKey(t, 'lesson_next', ms: 600);
  }
  expect(find.byKey(const ValueKey('practice_prompt')), findsOneWidget);
}

void main() {
  testWidgets('Learn with Sammy: read a chapter, practise, finish, earn a star', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final child = env!.store.addChild(alias: 'Mo', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_lessons');
    expect(find.text('0 of 8 chapters finished'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget, reason: 'the first chapter is suggested');

    await tapKey(t, 'chapter_body_talks');
    expect(find.text('1 / 7'), findsOneWidget);
    expect(env.speech.spoken.last, contains('My Body Talks. My body tells me how I feel.'));
    await tapKey(t, 'lesson_next', ms: 600);
    expect(find.text('2 / 7'), findsOneWidget);
    await tapKey(t, 'lesson_back', ms: 600);
    expect(find.text('1 / 7'), findsOneWidget);
    await toPractice(t, 6);
    expect(find.text('Finish'), findsOneWidget);

    await tapKey(t, 'choose_1');
    expect(find.byKey(const ValueKey('practice_reply')), findsOneWidget);
    expect(env.speech.spoken.last, contains('My tummy.'));
    await tapKey(t, 'lesson_next');
    expect(find.byKey(const ValueKey('lesson_done')), findsOneWidget);
    expect(env.sound.played, contains('sfx:done'));
    expect(child.lessonsDone, {'body_talks'});

    await tapKey(t, 'lesson_more');
    expect(find.text('1 of 8 chapters finished'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final sess = env.store.sessionsFor(child.id).where((s) => s.mode == 'lesson').single;
    expect((sess.sound, sess.stepsDone, sess.stepsTotal, sess.isFinished), ('body_talks', 7, 7, true));
  });

  testWidgets('Next always works: a chapter can be finished without doing the practice', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final child = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_lessons');
    await tapKey(t, 'chapter_asking_help');
    await toPractice(t, 5);
    await tapKey(t, 'lesson_next');
    expect(find.byKey(const ValueKey('lesson_done')), findsOneWidget);
    expect(child.lessonsDone, contains('asking_help'));
    await tapKey(t, 'home');
  });

  testWidgets('squeeze practice: press and hold three times', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_lessons');
    await tapKey(t, 'chapter_calm_tools');
    await toPractice(t, 6);
    final ball = find.byKey(const ValueKey('squeeze_ball'));
    for (var i = 0; i < 3; i++) {
      final g = await t.startGesture(t.getCenter(ball));
      await settle(t, 600);
      expect(find.text('Squeeze…'), findsOneWidget);
      await g.up();
      await settle(t, 600);
    }
    expect(find.byKey(const ValueKey('practice_reply')), findsOneWidget);
    expect(env.speech.spoken, contains('Squeeze and let go. Your hands feel softer now.'));
  });

  testWidgets('count practice: 5-4-3 grounding with stars', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_lessons');
    await tapKey(t, 'chapter_waiting_turn');
    await toPractice(t, 5);
    for (final n in [5, 4, 3]) {
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(n));
      for (var i = 0; i < n; i++) {
        await t.tap(find.byKey(const ValueKey('count_star_0'))); // any star lights the next one
        await t.pump(const Duration(milliseconds: 100));
      }
      await settle(t, 1200);
    }
    expect(find.byKey(const ValueKey('practice_reply')), findsOneWidget);
  });

  testWidgets('breathe practice: three slow breaths, then a reply', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_lessons');
    await tapKey(t, 'chapter_plans_change');
    await toPractice(t, 6);
    expect(find.text('Breath 1 of 3'), findsOneWidget);
    await settle(t, 31000);
    expect(find.byKey(const ValueKey('practice_reply')), findsOneWidget);
    expect(env.speech.spoken.where((x) => x == 'Breathe in').length, greaterThanOrEqualTo(3));
  });

  testWidgets('Picture Stories: read a story to the end', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final child = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await tapKey(t, 'card_stories');
    expect(find.text('My stories'), findsNothing, reason: 'no own stories yet');
    await tapKey(t, 'story_airplane');
    expect(find.text('1 / 7'), findsOneWidget);
    expect(env.speech.spoken.last, 'Going on an Airplane. Today I am going on an airplane.');
    for (var i = 0; i < 7; i++) {
      await tapKey(t, 'story_next', ms: 600);
    }
    expect(find.byKey(const ValueKey('story_end')), findsOneWidget);
    expect(env.speech.spoken.last, 'The end.');
    await tapKey(t, 'story_again');
    expect(find.text('1 / 7'), findsOneWidget);
    await tapKey(t, 'home');
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final sess = env.store.sessionsFor(child.id).where((s) => s.mode == 'story').single;
    expect((sess.sound, sess.isFinished), ('airplane', true));
  });

  testWidgets('grown-ups copy a story, personalise it, and it appears under My stories', (t) async {
    phone(t);
    final env = await t.runAsync(() => makeEnv());
    final child = env!.store.addChild(alias: 'A', ageGroup: '5-7');
    await t.pumpWidget(env.app());
    await settle(t);
    await passGate(t);
    await tapKey(t, 'tab_stories');
    expect(find.textContaining('No stories of your own yet'), findsOneWidget);
    await tapKey(t, 'add_story');
    await t.tap(find.byKey(const ValueKey('story_copy_airplane')));
    await settle(t);
    expect(find.text('New story'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('story_title_field')), 'Flying to Karachi');
    await tapKey(t, 'add_page');
    await t.enterText(find.byKey(const ValueKey('page_text')), 'Nani will meet us at the airport.');
    await tapKey(t, 'page_done');
    await tapKey(t, 'save_story');
    final st = env.store.storiesFor(child.id).single;
    expect(st.title, 'Flying to Karachi');
    expect(st.pages.length, 8);
    expect(st.pages.last.text, 'Nani will meet us at the airport.');

    Navigator.of(t.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
    await settle(t);
    await tapKey(t, 'card_stories');
    expect(find.text('My stories'), findsOneWidget);
    await tapKey(t, 'story_${st.id}');
    expect(find.text('1 / 8'), findsOneWidget);
  });

  // Real test phones: Galaxy A12 (720 px at 340 dp, text x1.3) and the owner's
  // OPPO CPH2743 (1080 px at 320 dp, text x1.15).
  for (final (name, px, h, dp, text) in [
    ('Galaxy A12', 720.0, 1600.0, 340.0, 1.3),
    ('OPPO CPH2743', 1080.0, 2372.0, 320.0, 1.15),
  ]) {
    testWidgets('$name ($dp dp, text x$text): hub, lessons and stories never cut words off', (t) async {
      t.view.physicalSize = Size(px, h);
      t.view.devicePixelRatio = px / dp;
      t.view.padding = FakeViewPadding(top: 24 * px / dp, bottom: 48 * px / dp);
      t.view.viewPadding = FakeViewPadding(top: 24 * px / dp, bottom: 48 * px / dp);
      t.platformDispatcher.textScaleFactorTestValue = text;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final env = await t.runAsync(() => makeEnv());
      env!.store.addChild(alias: 'Maya', ageGroup: '5-7');
      await t.pumpWidget(env.app());
      await settle(t);

      void check(String where) {
        for (final p in t.allRenderObjects.whereType<RenderParagraph>()) {
          expect(p.didExceedMaxLines, isFalse, reason: '$where: "${p.text.toPlainText()}" is cut off');
        }
        expect(t.takeException(), isNull, reason: where);
      }

      check('hub');
      await tapKey(t, 'card_lessons');
      check('chapter list');
      for (final id in ['body_talks', 'feeling_names', 'too_loud', 'waiting_turn']) {
        await tapKey(t, 'chapter_$id');
        check('$id card 1');
        final cards = testLearning.chapter(id)!.cards.length;
        for (var i = 0; i < cards; i++) {
          await tapKey(t, 'lesson_next', ms: 500);
          check('$id page ${i + 2}');
        }
        await tapKey(t, 'home');
        await tapKey(t, 'card_lessons');
      }
      await tapKey(t, 'home');
      await tapKey(t, 'card_stories');
      check('story list');
      await tapKey(t, 'story_wedding');
      for (var i = 0; i < 7; i++) {
        check('wedding page ${i + 1}');
        await tapKey(t, 'story_next', ms: 500);
      }
      check('story end');
      await tapKey(t, 'home');
    });
  }
}
