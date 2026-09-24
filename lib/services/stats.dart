// "Calm & Focus Horizon" metrics (PDD Step 5), computed on the device.

import '../core/content.dart';
import '../models/models.dart';

class RankedItem {
  final String label;
  final int count;
  final int seconds;
  RankedItem(this.label, this.count, this.seconds);
  double get avgMinutes => count == 0 ? 0 : seconds / count / 60;
}

class RoutineSummary {
  final String title;
  final int runs;
  final int finished;
  final int stepsDone;
  final int stepsTotal;
  RoutineSummary(this.title, this.runs, this.finished, this.stepsDone, this.stepsTotal);
}

class ChildStats {
  final DateTime from;
  final DateTime to;

  /// Calm minutes (Flow Canvas + Soothing Sounds) per day, oldest first.
  final List<({DateTime day, double minutes})> daily;
  final int calmSeconds;
  final int calmSessions;
  final int routineRuns;
  final int routinesFinished;
  final int stepsDone;
  final int stepsTotal;

  /// Top calming modes by total time: "Flow Canvas (Lavender)", "Soft Rain", ...
  final List<RankedItem> topModes;

  /// Preference matrix: average session length per palette and per sound.
  final List<RankedItem> palettes;
  final List<RankedItem> sounds;
  final Map<String, int> touchRhythms;
  final List<RoutineSummary> routines;

  ChildStats({
    required this.from,
    required this.to,
    required this.daily,
    required this.calmSeconds,
    required this.calmSessions,
    required this.routineRuns,
    required this.routinesFinished,
    required this.stepsDone,
    required this.stepsTotal,
    required this.topModes,
    required this.palettes,
    required this.sounds,
    required this.touchRhythms,
    required this.routines,
  });

  int get calmMinutes => (calmSeconds / 60).round();

  /// Step completion rate across started routine runs (PDD metric 2), 0..1.
  double? get stepCompletionRate => stepsTotal == 0 ? null : stepsDone / stepsTotal;

  bool get isEmpty => calmSessions == 0 && routineRuns == 0;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

List<RankedItem> _rank(Map<String, (int, int)> m, {bool byAverage = false}) {
  final list = [for (final e in m.entries) RankedItem(e.key, e.value.$1, e.value.$2)];
  list.sort((a, b) => byAverage ? b.avgMinutes.compareTo(a.avgMinutes) : b.seconds.compareTo(a.seconds));
  return list;
}

void _add(Map<String, (int, int)> m, String k, int secs) {
  final v = m[k] ?? (0, 0);
  m[k] = (v.$1 + 1, v.$2 + secs);
}

ChildStats computeStats(List<SensorySession> all, {int days = 7, DateTime? now}) {
  final end = now ?? DateTime.now();
  final firstDay = _day(end).subtract(Duration(days: days - 1));
  final sessions = all.where((s) => !s.start.toLocal().isBefore(firstDay)).toList();

  final perDay = <DateTime, int>{};
  var calmSecs = 0, calmCount = 0, runs = 0, finished = 0, done = 0, total = 0;
  final modes = <String, (int, int)>{};
  final pal = <String, (int, int)>{};
  final snd = <String, (int, int)>{};
  final rhythm = <String, int>{};
  final routineMap = <String, List<SensorySession>>{};

  for (final s in sessions) {
    if (s.isCalming) {
      calmSecs += s.durationSeconds;
      calmCount++;
      final d = _day(s.start.toLocal());
      perDay[d] = (perDay[d] ?? 0) + s.durationSeconds;
      if (s.mode == 'flow_canvas') {
        final p = s.palette ?? 'lavender';
        _add(modes, 'Flow Canvas (${paletteNames[p] ?? p})', s.durationSeconds);
        _add(pal, paletteNames[p] ?? p, s.durationSeconds);
        if (s.touchRhythm != null) rhythm[s.touchRhythm!] = (rhythm[s.touchRhythm!] ?? 0) + 1;
      } else {
        final n = soundTitles[s.sound] ?? 'Sounds';
        _add(modes, n, s.durationSeconds);
        _add(snd, n, s.durationSeconds);
      }
    } else if (s.mode == 'routine') {
      runs++;
      if (s.stepsTotal > 0 && s.stepsDone >= s.stepsTotal) finished++;
      done += s.stepsDone;
      total += s.stepsTotal;
      _add(modes, s.routineTitle ?? 'Visual Routine', s.durationSeconds);
      routineMap.putIfAbsent(s.routineTitle ?? 'Routine', () => []).add(s);
    } else if (s.mode == 'wait_timer') {
      _add(modes, 'Wait Timer', s.durationSeconds);
    }
  }

  final routines = [
    for (final e in routineMap.entries)
      RoutineSummary(
        e.key,
        e.value.length,
        e.value.where((s) => s.stepsTotal > 0 && s.stepsDone >= s.stepsTotal).length,
        e.value.fold(0, (a, s) => a + s.stepsDone),
        e.value.fold(0, (a, s) => a + s.stepsTotal),
      ),
  ]..sort((a, b) => b.runs.compareTo(a.runs));

  return ChildStats(
    from: firstDay,
    to: end,
    daily: [
      for (var i = 0; i < days; i++)
        (
          day: firstDay.add(Duration(days: i)),
          minutes: (perDay[firstDay.add(Duration(days: i))] ?? 0) / 60,
        ),
    ],
    calmSeconds: calmSecs,
    calmSessions: calmCount,
    routineRuns: runs,
    routinesFinished: finished,
    stepsDone: done,
    stepsTotal: total,
    topModes: _rank(modes),
    palettes: _rank(pal, byAverage: true),
    sounds: _rank(snd, byAverage: true),
    touchRhythms: rhythm,
    routines: routines,
  );
}

/// Touches per minute -> the PDD's avg_touch_frequency label.
String touchRhythmLabel(int touches, int seconds) {
  if (seconds <= 0) return 'steady';
  final perMin = touches / (seconds / 60);
  if (perMin < 20) return 'slow_rhythmic';
  if (perMin < 60) return 'steady';
  return 'busy';
}

const rhythmNames = {
  'slow_rhythmic': 'Slow & rhythmic',
  'steady': 'Steady',
  'busy': 'Busy',
};
