// v1.2: Learn with Sammy and Picture Stories — content integrity, data model,
// local store, cloud mirror and stats.

import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safescape/core/content.dart';
import 'package:safescape/core/learning.dart';
import 'package:safescape/models/models.dart';
import 'package:safescape/services/cloud_sync.dart';
import 'package:safescape/services/report.dart';
import 'package:safescape/services/stats.dart';
import 'package:safescape/services/store.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('content (assets/content/*.json)', () {
    final content = testLearning;

    test('8 chapters and 12 stories, as locked in docs/v1.2-scope.md', () {
      expect(content.chapters.map((c) => c.id), [
        'body_talks', 'feeling_names', 'calm_tools', 'too_loud',
        'plans_change', 'asking_help', 'waiting_turn', 'playing_together',
      ]);
      expect(content.stories.length, 12);
    });

    test('ids are unique', () {
      expect(content.chapters.map((c) => c.id).toSet().length, content.chapters.length);
      expect(content.stories.map((s) => s.id).toSet().length, content.stories.length);
    });

    test('every picture used exists and is a known pictogram', () {
      final keys = <String>{};
      for (final c in content.chapters) {
        keys.add(c.icon);
        keys.addAll(c.cards.map((x) => x.icon));
        keys.addAll(c.practice.options.map((o) => o.icon));
        keys.addAll(c.practice.steps.map((s) => s.icon));
      }
      for (final s in content.stories) {
        keys.add(s.icon);
        keys.addAll(s.pages.map((p) => p.icon));
      }
      for (final k in keys) {
        expect(iconLabels.containsKey(k), isTrue, reason: '$k is not in iconLabels');
        expect(File('assets/icons/$k.png').existsSync(), isTrue, reason: '$k.png missing');
      }
    });

    test('chapters: 5–6 short cards and a well-formed, errorless practice', () {
      for (final c in content.chapters) {
        expect(c.cards.length, inInclusiveRange(5, 6), reason: c.id);
        expect(['lavender', 'mint', 'sand', 'blue'], contains(c.color), reason: c.id);
        for (final card in c.cards) {
          expect(card.text.trim(), isNotEmpty);
          expect(card.text.split(' ').length, lessThanOrEqualTo(14), reason: 'keep cards short: "${card.text}"');
        }
        final p = c.practice;
        expect(p.prompt, isNotEmpty, reason: c.id);
        expect(p.reply, isNotEmpty, reason: c.id);
        switch (p.type) {
          case PracticeType.choose:
            expect(p.options.length, inInclusiveRange(2, 6), reason: c.id);
          case PracticeType.count:
            expect(p.steps, isNotEmpty, reason: c.id);
            expect(p.steps.every((s) => s.count >= 1 && s.count <= 5), isTrue, reason: c.id);
          case PracticeType.breathe || PracticeType.squeeze:
            expect(p.repeats, inInclusiveRange(1, 5), reason: c.id);
        }
      }
      // All four practice kinds are used somewhere.
      expect(content.chapters.map((c) => c.practice.type).toSet(), PracticeType.values.toSet());
    });

    test('stories: 5–7 pages, short first-person sentences, no scary wording', () {
      for (final s in content.stories) {
        expect(s.pages.length, inInclusiveRange(5, 7), reason: s.id);
        for (final p in s.pages) {
          expect(p.text.split(' ').length, lessThanOrEqualTo(20), reason: '${s.id}: "${p.text}"');
          for (final w in ['hurt', 'pain', 'needle', 'scream', 'danger', 'die', 'bad']) {
            expect(p.text.toLowerCase().split(RegExp(r'[^a-z]+')).contains(w), isFalse,
                reason: '${s.id}: "$w" in "${p.text}"');
          }
        }
      }
    });

    test('the trademarked term "Social Stories" is not used', () {
      final all = File('assets/content/stories.json').readAsStringSync() +
          File('assets/content/lessons.json').readAsStringSync();
      expect(all.toLowerCase().contains('social stor'), isFalse);
    });

    test('malformed content is skipped, never a crash', () {
      expect(LearningContent.parse('not json', '{"stories": 5}').chapters, isEmpty);
      final c = LearningContent.parse(
        jsonEncode({
          'chapters': [
            {'id': '', 'cards': []},
            {'id': 'ok', 'title': 'Ok', 'cards': [{'text': 'Hi'}], 'practice': {'type': 'weird'}},
            42,
          ],
        }),
        '{"stories": [{"id": "s", "pages": []}]}',
      );
      expect(c.chapters.single.id, 'ok');
      expect(c.chapters.single.practice.type, PracticeType.breathe);
      expect(c.stories, isEmpty);
    });
  });

  group('model and store', () {
    late Directory dir;
    File file() => File('${dir.path}/s.json');
    setUp(() async => dir = await Directory.systemTemp.createTemp('learn_test'));
    tearDown(() async => dir.delete(recursive: true));

    PictureStory story(String childId, {String? photo}) => PictureStory(
      id: newId('story'),
      childId: childId,
      title: 'Grandma\'s house',
      iconKey: 'home',
      pages: [StoryPage(id: newId('page'), text: 'We drive to Grandma.', iconKey: 'car', photoPath: photo)],
    );

    test('finished chapters and stories survive a restart; old files without them still load', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final c = store.addChild(alias: 'A', ageGroup: '5-7');
      store.completeLesson(c, 'calm_tools');
      store.completeLesson(c, 'calm_tools');
      store.upsertStory(story(c.id));
      await store.flush();
      final again = await AppStore.load(file(), OfflineCloudSync());
      expect(again.activeChild!.lessonsDone, {'calm_tools'});
      expect(again.storiesFor(c.id).single.pages.single.text, 'We drive to Grandma.');

      // A v1.1 file has neither field.
      final j = jsonDecode(await file().readAsString()) as Map<String, dynamic>;
      j.remove('picture_stories');
      (j['children'] as List).first.remove('lessons_done');
      await file().writeAsString(jsonEncode(j));
      final old = await AppStore.load(file(), OfflineCloudSync());
      expect(old.activeChild!.lessonsDone, isEmpty);
      expect(old.data.stories, isEmpty);
    });

    test('story photos stay local; deleting a child or a story removes its stories and photos', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final a = store.addChild(alias: 'A', ageGroup: '5-7');
      final b = store.addChild(alias: 'B', ageGroup: '5-7');
      final photo = File('${dir.path}/p.jpg')..writeAsStringSync('x');
      final st = story(a.id, photo: photo.path);
      expect(st.toJson(forCloud: true).toString().contains('photo'), isFalse);
      store.upsertStory(st);
      store.upsertStory(story(b.id));
      store.deleteStory(st);
      expect(photo.existsSync(), isFalse);
      expect(store.storiesFor(a.id), isEmpty);
      store.deleteChild(b.id);
      expect(store.data.stories, isEmpty);
    });

    test('merge: stories union with local photos kept; finished chapters are a union', () async {
      final store = await AppStore.load(file(), OfflineCloudSync());
      final c = store.addChild(alias: 'A', ageGroup: '5-7');
      store.completeLesson(c, 'body_talks');
      final local = story(c.id, photo: '/local/p.jpg');
      store.upsertStory(local);

      final cloudChild = ChildProfile.fromJson(c.toJson())
        ..lessonsDone = {'too_loud'}
        ..updatedAt = DateTime.now().add(const Duration(hours: 1));
      final cloudStory = PictureStory.fromJson(local.toJson(forCloud: true))
        ..title = 'Renamed'
        ..updatedAt = DateTime.now().add(const Duration(hours: 1));
      store.mergeFrom(CloudSnapshot([cloudChild], [], [], [cloudStory, story(c.id)]));

      expect(store.activeChild!.lessonsDone, {'body_talks', 'too_loud'});
      expect(store.storiesFor(c.id).length, 2);
      final merged = store.storyById(local.id)!;
      expect(merged.title, 'Renamed');
      expect(merged.pages.single.photoPath, '/local/p.jpg');
    });

    test('Firestore mirror: stories under children/{id}/stories without photos; account deletion removes them', () async {
      final db = FakeFirebaseFirestore();
      final cloud = FirebaseCloudSync(auth: MockFirebaseAuth(), db: db);
      await cloud.ensureSignedIn();
      final uid = cloud.uid!;
      final store = await AppStore.load(file(), cloud);
      final c = store.addChild(alias: 'A', ageGroup: '5-7');
      store.completeLesson(c, 'asking_help');
      store.upsertStory(story(c.id, photo: '/secret/photo.jpg'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final docs = await db.collection('users/$uid/children/${c.id}/stories').get();
      expect(docs.docs.single.data()['title'], 'Grandma\'s house');
      expect(jsonEncode(docs.docs.single.data()).contains('photo'), isFalse);
      final kid = await db.doc('users/$uid/children/${c.id}').get();
      expect(kid.data()!['lessons_done'], ['asking_help']);

      final snap = await cloud.pullAll();
      expect(snap!.stories.single.title, 'Grandma\'s house');

      expect(await cloud.deleteAccount(), isNull);
      expect((await db.collection('users/$uid/children/${c.id}/stories').get()).docs, isEmpty);
    });
  });

  group('stats and PDF', () {
    final now = DateTime(2026, 11, 4, 18);
    SensorySession s(String mode, String id, String title, int done, int total) => SensorySession(
      id: newId('s'), childId: 'c', mode: mode, start: now, durationSeconds: 60,
      sound: id, routineTitle: title, stepsDone: done, stepsTotal: total,
    );

    test('lessons and stories are counted, finished only when read to the end', () {
      final st = computeStats([
        s('lesson', 'calm_tools', 'My Calm-Down Tools', 7, 7),
        s('lesson', 'calm_tools', 'My Calm-Down Tools', 3, 7),
        s('story', 'airplane', 'Going on an Airplane', 7, 7),
      ], now: now);
      expect(st.isEmpty, isFalse);
      expect(st.lessonsFinished, 1);
      expect(st.storiesFinished, 1);
      final calm = st.learning.firstWhere((l) => l.title == 'My Calm-Down Tools');
      expect((calm.visits, calm.finished, calm.isStory), (2, 1, false));
      expect(st.calmSeconds, 0, reason: 'learning is not counted as calm time');
    });

    test('steps survive a JSON round trip for lessons and stories', () {
      final back = SensorySession.fromJson(s('story', 'x', 'X', 4, 6).toJson());
      expect((back.stepsDone, back.stepsTotal), (4, 6));
    });

    test('the OT PDF includes the Learning section', () async {
      final child = ChildProfile(id: 'c', alias: 'Sunny', ageGroup: '5-7', lessonsDone: {'calm_tools'});
      final bytes = await buildReport(child: child, now: now, sessions: [s('lesson', 'calm_tools', 'My Calm-Down Tools', 7, 7)]);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
