import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safescape/core/content.dart';
import 'package:safescape/models/models.dart';
import 'package:safescape/services/cloud_sync.dart';
import 'package:safescape/services/store.dart';

void main() {
  late Directory dir;
  File file() => File('${dir.path}/safescape.json');

  setUp(() async => dir = await Directory.systemTemp.createTemp('store_test'));
  tearDown(() async => dir.delete(recursive: true));

  group('models', () {
    test('sensory profile: Mute High Pitch caps the cutoff at 4 kHz', () {
      final s = SensoryProfile(audioCutoffHz: 6000, muteHighPitch: true);
      expect(s.effectiveCutoffHz, 4000);
      expect(s.audioVariant, '4k');
      s.muteHighPitch = false;
      expect(s.audioVariant, '6k');
      s.audioCutoffHz = 2500;
      expect(s.audioVariant, '2k5');
    });

    test('Low Motion halves the motion factor', () {
      final s = SensoryProfile(motionSpeed: 0.8);
      expect(s.motionFactor, closeTo(0.8, 1e-9));
      s.lowMotion = true;
      expect(s.motionFactor, closeTo(0.4, 1e-9));
    });

    test('malformed JSON falls back field by field instead of throwing', () {
      final c = ChildProfile.fromJson({
        'alias_name': 42,
        'age_group': 'teen',
        'sensory_profile': {'particle_density': 9, 'audio_cutoff_hz': 1234, 'palette': 'neon'},
      });
      expect(c.alias, 'Friend');
      expect(c.ageGroup, '5-7');
      expect(c.sensory.particleDensity, 1.0);
      expect(c.sensory.audioCutoffHz, 6000);
      expect(c.sensory.palette, 'lavender');
      final d = AppData.fromJson({'children': [1, 'x', null], 'visual_routines': 'nope'});
      expect(d.children, isEmpty);
      expect(d.routines, isEmpty);
    });

    test('photos are kept locally but never sent to the cloud', () {
      final s = RoutineStep(id: 's', title: 'Shoes', iconKey: 'shoes', photoPath: '/data/p.jpg');
      expect(s.toJson().containsKey('photo_path'), isTrue);
      expect(s.toJson(forCloud: true).containsKey('photo_path'), isFalse);
    });

    test('ids are unique', () {
      final ids = {for (var i = 0; i < 2000; i++) newId('x')};
      expect(ids.length, 2000);
    });
  });

  group('store', () {
    test('first child gets the eight starter routines and survives a restart', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      expect(store.onboarded, isFalse);
      final c = store.addChild(alias: '  Sunny ', ageGroup: '2-4');
      expect(c.alias, 'Sunny');
      expect(c.sensory.lowMotion, isTrue, reason: 'L16: calm motion by default for ages 2-4');
      expect(store.routinesFor(c.id).length, routineTemplates.length);
      await store.flush();

      final again = await AppStore.load(file(), OfflineCloudSync());
      expect(again.activeChild!.alias, 'Sunny');
      expect(again.routinesFor(c.id).length, routineTemplates.length);
    });

    test('an empty nickname becomes "Friend"', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      expect(store.addChild(alias: '', ageGroup: '5-7').alias, 'Friend');
    });

    test('a corrupt file is set aside and the app starts fresh', () async {
      await file().writeAsString('{not json');
      final store = await AppStore.load(file(), OfflineCloudSync());
      expect(store.onboarded, isFalse);
      expect(File('${file().path}.corrupt').existsSync(), isTrue);
    });

    test('rapid saves never leave a half-written file', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final c = store.addChild(alias: 'A', ageGroup: '5-7');
      for (var i = 0; i < 50; i++) {
        c.alias = 'Name $i';
        store.updateChild(c);
        store.flush();
      }
      await store.flush();
      final j = jsonDecode(await file().readAsString()) as Map<String, dynamic>;
      expect((j['children'] as List).first['alias_name'], 'Name 49');
    });

    test('completing steps records one routine run with its progress', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final c = store.addChild(alias: 'A', ageGroup: '5-7');
      final r = store.routinesFor(c.id).first;
      final n = r.steps.length;
      expect(store.completeStep(r, 1), isFalse, reason: 'any index can be completed by the store');
      expect(store.completeStep(r, 1), isFalse, reason: 'double tap is ignored');
      var runs = store.sessionsFor(c.id).where((s) => s.mode == 'routine').toList();
      expect(runs.length, 1);
      expect(runs.single.stepsDone, 1);
      expect(runs.single.stepsTotal, n);
      var finished = false;
      for (var i = 0; i < n; i++) {
        finished = store.completeStep(r, i) || finished;
      }
      expect(finished, isTrue);
      expect(r.isFinished, isTrue);
      expect(r.activeRunId, isNull);
      runs = store.sessionsFor(c.id).where((s) => s.mode == 'routine').toList();
      expect(runs.single.stepsDone, n);

      store.resetRoutine(r);
      expect(r.doneCount, 0);
      store.completeStep(r, 0);
      expect(store.sessionsFor(c.id).where((s) => s.mode == 'routine').length, 2, reason: 'a new run starts');
    });

    test('deleting a child removes its routines and sessions and picks another active child', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final a = store.addChild(alias: 'A', ageGroup: '5-7');
      final b = store.addChild(alias: 'B', ageGroup: '8-10');
      expect(store.activeChild!.id, b.id);
      store.logSession(SensorySession(id: newId('s'), childId: b.id, mode: 'sounds', start: DateTime.now(), durationSeconds: 60));
      store.deleteChild(b.id);
      expect(store.activeChild!.id, a.id);
      expect(store.routinesFor(b.id), isEmpty);
      expect(store.sessionsFor(b.id), isEmpty);
    });

    test('session history is capped', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final c = store.addChild(alias: 'A', ageGroup: '5-7');
      final t0 = DateTime(2026, 1, 1);
      for (var i = 0; i < AppStore.maxSessions + 20; i++) {
        store.data.sessions.add(SensorySession(id: 's$i', childId: c.id, mode: 'sounds', start: t0.add(Duration(minutes: i))));
      }
      store.logSession(SensorySession(id: 'last', childId: c.id, mode: 'sounds', start: DateTime(2027)));
      expect(store.data.sessions.length, AppStore.maxSessions);
      expect(store.data.sessions.any((s) => s.id == 'last'), isTrue);
      expect(store.data.sessions.any((s) => s.id == 's0'), isFalse, reason: 'oldest are dropped');
    });

    test('merge: union by id, newest wins, local photos are kept', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final c = store.addChild(alias: 'Local', ageGroup: '5-7');
      final r = store.routinesFor(c.id).first;
      r.steps.first.photoPath = '/local/photo.jpg';

      final cloudRoutine = Routine.fromJson(r.toJson(forCloud: true))
        ..title = 'Renamed in cloud'
        ..updatedAt = DateTime.now().add(const Duration(hours: 1));
      final other = ChildProfile(id: 'child_cloud', alias: 'Cloud kid', ageGroup: '8-10');
      store.mergeFrom(CloudSnapshot([other], [cloudRoutine], [
        SensorySession(id: 'cloud_s', childId: other.id, mode: 'sounds', start: DateTime.now(), durationSeconds: 30),
      ]));
      expect(store.data.children.map((c) => c.alias), containsAll(['Local', 'Cloud kid']));
      final merged = store.routineById(r.id)!;
      expect(merged.title, 'Renamed in cloud');
      expect(merged.steps.first.photoPath, '/local/photo.jpg');
      expect(store.sessionsFor(other.id).length, 1);
    });

    test('wipe erases everything', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      store.addChild(alias: 'A', ageGroup: '5-7');
      await store.wipe();
      expect(store.onboarded, isFalse);
      final again = await AppStore.load(file(), OfflineCloudSync());
      expect(again.onboarded, isFalse);
    });
  });

  group('cloud mirror (Firestore)', () {
    test('mirrors children, routines and sessions under users/{uid}', () async {
      final db = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth();
      final cloud = FirebaseCloudSync(auth: auth, db: db);
      await cloud.ensureSignedIn();
      expect(cloud.signedIn, isTrue);
      expect(cloud.isAnonymous, isTrue);
      final uid = cloud.uid!;

      final store = await AppStore.load(file(), cloud);
      final c = store.addChild(alias: 'Sky', ageGroup: '5-7');
      final r = store.routinesFor(c.id).first;
      r.steps.first.photoPath = '/private/photo.jpg';
      store.completeStep(r, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final child = await db.doc('users/$uid/children/${c.id}').get();
      expect(child.data()!['alias_name'], 'Sky');
      expect(child.data()!.containsKey('parent_email'), isFalse);
      final routines = await db.collection('users/$uid/children/${c.id}/routines').get();
      expect(routines.docs.length, routineTemplates.length);
      final doc = routines.docs.firstWhere((d) => d.id == r.id).data();
      expect(jsonEncode(doc).contains('photo'), isFalse, reason: 'L6: photos never leave the device');
      final sessions = await db.collection('users/$uid/children/${c.id}/sessions').get();
      expect(sessions.docs.single.data()['steps_done'], 1);

      // A fresh device pulls the same data back.
      final snap = await cloud.pullAll();
      expect(snap!.children.single.alias, 'Sky');
      expect(snap.routines.length, routineTemplates.length);
      expect(snap.sessions.length, 1);
    });

    test('with backup switched off nothing is written', () async {
      final db = FakeFirebaseFirestore();
      final cloud = FirebaseCloudSync(auth: MockFirebaseAuth(), db: db);
      await cloud.ensureSignedIn();
      final store = await AppStore.load(file(), cloud);
      store.updateSettings((s) => s.cloudBackup = false);
      store.addChild(alias: 'Private', ageGroup: '5-7');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final kids = await db.collection('users/${cloud.uid}/children').get();
      expect(kids.docs, isEmpty);
    });

    test('switching backup on uploads everything', () async {
      final db = FakeFirebaseFirestore();
      final cloud = FirebaseCloudSync(auth: MockFirebaseAuth(), db: db);
      final store = await AppStore.load(file(), cloud);
      store.updateSettings((s) => s.cloudBackup = false);
      final c = store.addChild(alias: 'Later', ageGroup: '5-7');
      await store.setCloudBackup(true);
      final kids = await db.collection('users/${cloud.uid}/children').get();
      expect(kids.docs.single.id, c.id);
    });

    test('deleting the account removes every cloud document', () async {
      final db = FakeFirebaseFirestore();
      final cloud = FirebaseCloudSync(auth: MockFirebaseAuth(), db: db);
      await cloud.ensureSignedIn();
      final uid = cloud.uid!;
      final store = await AppStore.load(file(), cloud);
      final c = store.addChild(alias: 'Gone', ageGroup: '5-7');
      store.completeStep(store.routinesFor(c.id).first, 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await cloud.deleteAccount(), isNull);
      expect((await db.collection('users/$uid/children').get()).docs, isEmpty);
      expect((await db.collection('users/$uid/children/${c.id}/routines').get()).docs, isEmpty);
      expect((await db.collection('users/$uid/children/${c.id}/sessions').get()).docs, isEmpty);
      expect((await db.doc('users/$uid').get()).exists, isFalse);
    });
  });
}
