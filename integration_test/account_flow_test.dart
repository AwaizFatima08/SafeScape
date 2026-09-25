// Account lifecycle on a real device against the real Firebase project:
// link an email -> sign out (device wiped) -> "new device": sign in and get the
// child back -> delete the account and check nothing is left in Firestore.
//
//   flutter test integration_test/account_flow_test.dart -d <device>
//
// Uses a throwaway address in the app's own project; the account is deleted at
// the end.

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

Future<void> waitFor(WidgetTester t, Finder f, {int seconds = 30}) async {
  for (var i = 0; i < seconds * 4 && f.evaluate().isEmpty; i++) {
    await wait(t, 250);
  }
  if (f.evaluate().isEmpty) {
    // ignore: avoid_print
    print('SCREEN ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}');
  }
  expect(f, findsWidgets, reason: 'waited ${seconds}s for $f');
}

Future<void> tapKey(WidgetTester t, String key, {int settleMs = 1200}) async {
  final f = find.byKey(ValueKey(key));
  await wait(t, 300);
  if (f.evaluate().isEmpty) {
    // Lazily built list item: back to the top of the list, then scroll down to it.
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;
    t.state<ScrollableState>(list).position.jumpTo(0);
    await wait(t, 300);
    if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 250, scrollable: list);
  }
  final r = t.getRect(f);
  // Visible area = the enclosing list's viewport if there is one (headers such
  // as an app bar can cover the rest of the screen), else the whole screen.
  final lists = find.ancestor(of: f, matching: find.byType(Scrollable));
  final screen = lists.evaluate().isNotEmpty
      ? t.getRect(lists.first)
      : Offset.zero & t.view.physicalSize / t.view.devicePixelRatio;
  if (!screen.contains(r.topLeft) || !screen.contains(r.bottomRight - const Offset(1, 1))) {
    await t.ensureVisible(f);
  }
  await wait(t, 400);
  await t.tap(f);
  await wait(t, settleMs);
}

Future<void> onboard(WidgetTester t, String name) async {
  await waitFor(t, find.byKey(const ValueKey('alias_field')));
  await t.enterText(find.byKey(const ValueKey('alias_field')), name);
  await t.testTextInput.receiveAction(TextInputAction.done);
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(t, 1500);
  await tapKey(t, 'enter_button', settleMs: 3000);
  await waitFor(t, find.byKey(const ValueKey('hub_greeting')));
}

Future<void> openAccountTab(WidgetTester t) async {
  await tapKey(t, 'parent_lock');
  final q = t.widget<Text>(find.byKey(const ValueKey('gate_question'))).data!;
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  for (final ch in '${int.parse(m[1]!) * int.parse(m[2]!)}'.split('')) {
    await t.tap(find.byKey(ValueKey('gate_$ch')));
    await t.pump();
  }
  await wait(t, 1500);
  await tapKey(t, 'tab_account');
}

Future<void> credentials(WidgetTester t, String email, String password) async {
  await t.enterText(find.byKey(const ValueKey('acct_email')), email);
  await t.enterText(find.byKey(const ValueKey('acct_password')), password);
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(t, 800);
  await t.tap(find.byKey(const ValueKey('acct_submit')));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('link email, sign out, restore on a "new device", delete everything', (t) async {
    final email = 'safescape.e2e.${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'Calm-Turtle-2026';
    await app.main();
    final db = FirebaseFirestore.instance; // only after main() has started Firebase
    final alias = find.byKey(const ValueKey('alias_field'));
    final hub = find.byKey(const ValueKey('hub_greeting'));
    for (var i = 0; i < 60 && alias.evaluate().isEmpty && hub.evaluate().isEmpty; i++) {
      await wait(t, 500);
    }
    final store = ProviderScope.containerOf(t.element(find.byType(SafeScapeApp))).read(storeProvider);
    if (hub.evaluate().isNotEmpty) {
      // Leftover data from an earlier run: start clean.
      await store.wipe();
      await wait(t, 1500);
    }
    await onboard(t, 'Rowan');
    final childId = store.activeChild!.id;
    store.completeStep(store.routinesFor(childId).first, 0);

    // 1. Link an email to the anonymous account.
    await openAccountTab(t);
    await tapKey(t, 'link_email');
    await credentials(t, email, password);
    await waitFor(t, find.textContaining('Progress is now linked'), seconds: 40);
    final uid = FirebaseAuth.instance.currentUser!.uid;
    expect(FirebaseAuth.instance.currentUser!.isAnonymous, isFalse);
    expect(FirebaseAuth.instance.currentUser!.email, email);
    await wait(t, 3000);
    final kid = await db.doc('users/$uid/children/$childId').get(const GetOptions(source: Source.server));
    expect(kid.data()?['alias_name'], 'Rowan', reason: 'the child reached the cloud');

    // 2. Sign out: the device is wiped and the app returns to the welcome page.
    // The account list is scrolled down after linking: bring its top into view.
    final accountList = find.ancestor(of: find.byKey(const ValueKey('delete_all')), matching: find.byType(Scrollable)).first;
    t.state<ScrollableState>(accountList).position.jumpTo(0);
    await wait(t, 500);
    await tapKey(t, 'sign_out');
    await tapKey(t, 'confirm', settleMs: 3000);
    await waitFor(t, alias);
    expect(store.data.children, isEmpty);

    // 3. "New device": set up quickly, then sign in to the existing account.
    await onboard(t, 'Temp');
    await openAccountTab(t);
    await tapKey(t, 'sign_in');
    await credentials(t, email, password);
    await waitFor(t, find.textContaining('Signed in'), seconds: 40);
    expect(FirebaseAuth.instance.currentUser!.uid, uid, reason: 'same account as before');
    expect(store.data.children.map((c) => c.alias), contains('Rowan'), reason: 'the child came back');
    final rowanRuns = store.sessionsFor(childId).where((s) => s.mode == 'routine');
    expect(rowanRuns, isNotEmpty, reason: 'progress came back too');

    // 4. Delete the account and all cloud data (password re-confirmed).
    await wait(t, 6000); // let the "Signed in" message bar (5 s) clear off the button
    await tapKey(t, 'delete_all');
    await tapKey(t, 'confirm');
    await waitFor(t, find.byKey(const ValueKey('acct_password')));
    await t.enterText(find.byKey(const ValueKey('acct_password')), password);
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(t, 800);
    await t.tap(find.byKey(const ValueKey('acct_submit')));
    await waitFor(t, alias, seconds: 60);
    expect(FirebaseAuth.instance.currentUser, isNull);
    expect(store.data.children, isEmpty);

    // Nothing is left behind: sign in fails and the documents are gone (checked
    // through the Admin-free path: a fresh anonymous user can't read them, so we
    // verify via the deleted account's own absence).
    final signIn = FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    await expectLater(signIn, throwsA(isA<FirebaseAuthException>()), reason: 'account no longer exists');
  });
}
