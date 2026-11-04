// v1.2 on a real device or emulator, with real plugins and the real Firebase
// project: a Learn with Sammy chapter with the squeeze practice, a Picture
// Story read to the end, and a grown-up's own story mirrored to Firestore.
//
//   flutter test integration_test/learning_flow_test.dart -d <device>
//
// The Firebase project holds real families' data: this test deletes its own
// anonymous test account (and only that) at the end.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;
    await t.scrollUntilVisible(f, 250, scrollable: list);
  }
  final lists = find.ancestor(of: f, matching: find.byType(Scrollable));
  final r = t.getRect(f);
  final area = lists.evaluate().isNotEmpty ? t.getRect(lists.first) : Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  if (!area.contains(r.topLeft) || !area.contains(r.bottomRight - const Offset(1, 1))) await t.ensureVisible(f);
  await wait(t, 400);
  await t.tap(f);
  await wait(t, settleMs);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lesson, story and an own story on a real device', (t) async {
    await app.main();
    final alias = find.byKey(const ValueKey('alias_field'));
    final hub = find.byKey(const ValueKey('hub_greeting'));
    for (var i = 0; i < 60 && alias.evaluate().isEmpty && hub.evaluate().isEmpty; i++) {
      await wait(t, 500);
    }
    final container = ProviderScope.containerOf(t.element(find.byType(SafeScapeApp)));
    final store = container.read(storeProvider);
    if (hub.evaluate().isNotEmpty) {
      await store.wipe();
      await wait(t, 1500);
    }
    await t.enterText(alias, 'Tester');
    await t.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(t, 1500);
    await tapKey(t, 'enter_button', settleMs: 3000);
    expect(hub, findsOneWidget);
    final childId = store.activeChild!.id;

    // Learn with Sammy: My Calm-Down Tools, squeeze practice for real.
    await tapKey(t, 'card_lessons');
    expect(find.text('0 of 8 chapters finished'), findsOneWidget);
    await tapKey(t, 'chapter_calm_tools');
    for (var i = 0; i < 6; i++) {
      await tapKey(t, 'lesson_next', settleMs: 900);
    }
    final ball = find.byKey(const ValueKey('squeeze_ball'));
    for (var i = 0; i < 3; i++) {
      final g = await t.startGesture(t.getCenter(ball));
      await wait(t, 1200);
      await g.up();
      await wait(t, 1200);
    }
    expect(find.byKey(const ValueKey('practice_reply')), findsOneWidget);
    await tapKey(t, 'lesson_next', settleMs: 2000);
    expect(find.byKey(const ValueKey('lesson_done')), findsOneWidget);
    await tapKey(t, 'lesson_more');
    expect(find.text('1 of 8 chapters finished'), findsOneWidget);
    await tapKey(t, 'home');

    // Picture Stories: When It Thunders, to the end.
    await tapKey(t, 'card_stories');
    await tapKey(t, 'story_thunder');
    for (var i = 0; i < 6; i++) {
      await tapKey(t, 'story_next', settleMs: 900);
    }
    expect(find.byKey(const ValueKey('story_end')), findsOneWidget);
    await tapKey(t, 'story_more');
    await tapKey(t, 'home');

    // Grown-ups: copy a story into "My stories".
    await tapKey(t, 'parent_lock');
    final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
    for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!)}'.split('')) {
      await t.tap(find.byKey(ValueKey('gate_$ch')));
      await t.pump();
    }
    await wait(t, 1500);
    await tapKey(t, 'tab_stories');
    await tapKey(t, 'add_story');
    await t.tap(find.byKey(const ValueKey('story_copy_wedding')));
    await wait(t, 1500);
    await tapKey(t, 'save_story', settleMs: 2000);
    expect(store.storiesFor(childId).single.title, 'Going to a Wedding');

    // The cloud mirror got the lesson star, both sessions and the own story.
    final cloud = container.read(cloudProvider);
    final user = FirebaseAuth.instance.currentUser;
    expect(user, isNotNull, reason: 'silent anonymous sign-in');
    await wait(t, 5000);
    final root = FirebaseFirestore.instance.doc('users/${user!.uid}/children/$childId');
    final kid = await root.get(const GetOptions(source: Source.server));
    expect(kid.data()?['lessons_done'], ['calm_tools']);
    final modes = (await root.collection('sessions').get(const GetOptions(source: Source.server)))
        .docs
        .map((d) => d.data()['mode_used'])
        .toSet();
    expect(modes, containsAll(['lesson', 'story']));
    final stories = await root.collection('stories').get(const GetOptions(source: Source.server));
    expect(stories.docs.single.data()['title'], 'Going to a Wedding');

    // Clean up: delete this test's own anonymous account and its data.
    expect(await cloud.deleteAccount(), isNull);
    expect(FirebaseAuth.instance.currentUser, isNull);
    // ignore: avoid_print
    print('CLEANED test account ${user.uid}');
  });
}
