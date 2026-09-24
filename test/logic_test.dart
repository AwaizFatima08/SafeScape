import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:safescape/core/content.dart';
import 'package:safescape/models/models.dart';
import 'package:safescape/services/report.dart';
import 'package:safescape/services/stats.dart';
import 'package:safescape/views/flow_sim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('breathing guide', () {
    test('4 seconds in, 6 seconds out', () {
      expect(FlowSim.breathAt(0).$1, closeTo(0, 1e-9));
      expect(FlowSim.breathAt(2).$2, isTrue);
      expect(FlowSim.breathAt(4).$1, closeTo(1, 1e-9));
      expect(FlowSim.breathAt(3.99).$2, isTrue);
      expect(FlowSim.breathAt(4.01).$2, isFalse);
      expect(FlowSim.breathAt(7).$1, closeTo(0.5, 1e-9));
      expect(FlowSim.breathAt(10).$1, closeTo(0, 1e-9));
      // Smooth: no jumps between frames.
      var prev = FlowSim.breathAt(0).$1;
      for (var t = 1 / 60; t < 30; t += 1 / 60) {
        final b = FlowSim.breathAt(t).$1;
        expect((b - prev).abs(), lessThan(0.02));
        prev = b;
      }
    });
  });

  group('flow simulation', () {
    FlowSim sim({double density = 1}) => FlowSim(density: density, seed: 1)..resize(const Size(400, 700));

    test('stays within the particle budget under frantic multi-touch', () {
      final s = sim();
      for (var f = 0; f < 600; f++) {
        for (var finger = 0; finger < 10; finger++) {
          s.touchDown(40.0 * finger, 70.0 * finger);
          s.touchMove(40.0 * finger + 5, 70.0 * finger + 5, 300, -250, 1 / 60);
        }
        s.step(1 / 60);
      }
      expect(s.particles.length, lessThanOrEqualTo(s.maxParticles));
      expect(s.ripples.length, lessThanOrEqualTo(18));
      for (final p in s.particles) {
        expect(p.x.isFinite && p.y.isFinite, isTrue);
        expect(p.x, inInclusiveRange(0, 400));
        expect(p.y, inInclusiveRange(0, 700));
      }
    });

    test('particles pushed into a wall fade instead of piling up', () {
      final s = sim();
      for (var f = 0; f < 120; f++) {
        s.touchMove(380, 350, 30, 0, 1 / 60); // hard swipes toward the right edge
        s.step(1 / 60);
      }
      for (var f = 0; f < 90; f++) {
        s.step(1 / 60);
      }
      final atWall = s.particles.where((p) => p.life > 0 && !p.ambient && p.x >= 399).length;
      expect(atWall, lessThan(5));
    });

    test('lower density means fewer particles', () {
      expect(sim(density: 0.2).maxParticles, lessThan(sim(density: 1).maxParticles));
    });

    test('dragging stirs the field, and it settles when the finger lifts', () {
      final s = sim();
      for (var i = 0; i < 10; i++) {
        s.touchMove(200, 350, 20, 0, 1 / 60);
      }
      expect(s.sampleField(200, 350).$1, greaterThan(50));
      for (var i = 0; i < 600; i++) {
        s.step(1 / 60);
      }
      expect(s.sampleField(200, 350).$1.abs(), lessThan(1));
    });

    test('ambient motes keep the canvas alive when nobody touches it', () {
      final s = sim(density: 0.6);
      for (var i = 0; i < 60 * 20; i++) {
        s.step(1 / 60);
      }
      expect(s.liveCount, greaterThan(5));
    });

    test('reset fades everything out gently', () {
      final s = sim();
      for (var i = 0; i < 30; i++) {
        s.touchDown(100, 100);
        s.step(1 / 60);
      }
      s.reset();
      for (final p in s.particles) {
        expect(p.life, lessThanOrEqualTo(0.25));
      }
      for (var i = 0; i < 60; i++) {
        s.step(1 / 60);
      }
      expect(s.particles.where((p) => p.life > 0 && !p.ambient).length, lessThan(40));
    });
  });

  group('stats', () {
    final now = DateTime(2026, 9, 24, 18);
    SensorySession sess(String mode, int daysAgo, int secs, {String? palette, String? sound, int done = 0, int total = 0, String? title}) =>
        SensorySession(
          id: newId('s'),
          childId: 'c',
          mode: mode,
          start: now.subtract(Duration(days: daysAgo)),
          durationSeconds: secs,
          palette: palette,
          sound: sound,
          stepsDone: done,
          stepsTotal: total,
          routineTitle: title,
          touchRhythm: mode == 'flow_canvas' ? 'slow_rhythmic' : null,
        );

    test('calm time, completion rate, rankings and the 7-day window', () {
      final st = computeStats([
        sess('flow_canvas', 0, 600, palette: 'mint'),
        sess('flow_canvas', 1, 300, palette: 'lavender'),
        sess('sounds', 2, 1200, sound: 'rain'),
        sess('sounds', 20, 9999, sound: 'hum'), // outside the window
        sess('routine', 0, 100, done: 4, total: 4, title: 'Bedtime'),
        sess('routine', 1, 50, done: 2, total: 4, title: 'Bedtime'),
      ], now: now);
      expect(st.calmSeconds, 2100);
      expect(st.calmMinutes, 35);
      expect(st.routineRuns, 2);
      expect(st.routinesFinished, 1);
      expect(st.stepCompletionRate, closeTo(0.75, 1e-9));
      expect(st.topModes.first.label, 'Soft Rain');
      expect(st.palettes.first.label, 'Mint');
      expect(st.daily.length, 7);
      expect(st.daily.last.minutes, closeTo(10, 1e-9));
      expect(st.routines.single.finished, 1);
      expect(st.touchRhythms['slow_rhythmic'], 2);
    });

    test('empty history', () {
      final st = computeStats([], now: now);
      expect(st.isEmpty, isTrue);
      expect(st.stepCompletionRate, isNull);
    });

    test('touch rhythm labels', () {
      expect(touchRhythmLabel(5, 60), 'slow_rhythmic');
      expect(touchRhythmLabel(40, 60), 'steady');
      expect(touchRhythmLabel(200, 60), 'busy');
      expect(touchRhythmLabel(3, 0), 'steady');
    });

    test('the OT PDF builds with and without data', () async {
      final child = ChildProfile(id: 'c', alias: 'Sunny', ageGroup: '5-7');
      final empty = await buildReport(child: child, sessions: [], now: now);
      expect(String.fromCharCodes(empty.take(5)), '%PDF-');
      final full = await buildReport(child: child, now: now, sessions: [
        for (var i = 0; i < 200; i++) sess(i.isEven ? 'flow_canvas' : 'sounds', i % 30, 120, palette: 'sand', sound: 'ocean'),
        sess('routine', 3, 100, done: 3, total: 5, title: 'Visiting the Doctor'),
      ]);
      expect(full.length, greaterThan(empty.length));
    });
  });

  group('bundled assets', () {
    test('every pictogram key has an image', () {
      for (final k in iconLabels.keys) {
        expect(File('assets/icons/$k.png').existsSync(), isTrue, reason: k);
      }
      for (final t in routineTemplates) {
        expect(iconLabels.containsKey(t.icon), isTrue, reason: t.title);
        for (final s in t.steps) {
          expect(iconLabels.containsKey(s.icon), isTrue, reason: '${t.title}: ${s.title}');
        }
      }
    });

    test('every sound exists at every cutoff, plus the effects', () {
      for (final n in soundNames) {
        for (final v in ['6k', '4k', '2k5']) {
          expect(File('assets/audio/loops/${n}_$v.wav').existsSync(), isTrue, reason: '${n}_$v');
        }
      }
      for (final n in ['tap', 'step', 'done', 'wait_end']) {
        expect(File('assets/audio/sfx/$n.wav').existsSync(), isTrue, reason: n);
      }
    });
  });
}
