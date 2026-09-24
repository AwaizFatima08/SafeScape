// Local-first store (docs/design-review-v1.md L3): one JSON file on the device
// is the source of truth. Every change is saved atomically and, when the parent
// allows cloud backup, mirrored to Firestore.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/content.dart';
import '../models/models.dart';
import 'cloud_sync.dart';

class AppStore extends ChangeNotifier {
  final File file;
  final CloudSync cloud;
  AppData data;
  Timer? _saveTimer;
  Future<void> _chain = Future.value();

  static const maxSessions = 5000;

  AppStore._(this.file, this.cloud, this.data);

  static Future<AppStore> load(File file, CloudSync cloud) async {
    AppData data;
    try {
      if (await file.exists()) {
        data = AppData.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      } else {
        data = AppData();
      }
    } catch (e) {
      // Keep the damaged file for inspection and start fresh rather than crash.
      debugPrint('Store unreadable, starting fresh: $e');
      try {
        await file.rename('${file.path}.corrupt');
      } catch (_) {}
      data = AppData();
    }
    final store = AppStore._(file, cloud, data);
    store._repair();
    return store;
  }

  /// Fix references that could dangle after edits or merges.
  void _repair() {
    final ids = data.children.map((c) => c.id).toSet();
    data.routines.removeWhere((r) => !ids.contains(r.childId));
    if (data.settings.activeChildId == null || !ids.contains(data.settings.activeChildId)) {
      data.settings.activeChildId = data.children.isEmpty ? null : data.children.first.id;
    }
  }

  // ---------- reads ----------

  bool get onboarded => data.children.isNotEmpty;
  GlobalSettings get settings => data.settings;

  ChildProfile? get activeChild {
    final id = data.settings.activeChildId;
    for (final c in data.children) {
      if (c.id == id) return c;
    }
    return data.children.isEmpty ? null : data.children.first;
  }

  List<Routine> routinesFor(String childId) =>
      data.routines.where((r) => r.childId == childId).toList();

  Routine? routineById(String id) {
    for (final r in data.routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<SensorySession> sessionsFor(String childId) =>
      data.sessions.where((s) => s.childId == childId).toList();

  // ---------- persistence ----------

  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), flush);
  }

  /// Writes the file now (atomic: temp file then rename). Writes are queued
  /// one after another, so overlapping saves can never clash.
  Future<void> flush() {
    _saveTimer?.cancel();
    final next = _chain.then((_) => _writeNow());
    _chain = next;
    return next;
  }

  Future<void> _writeNow() async {
    try {
      final json = jsonEncode(data.toJson());
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  bool get _mirror => data.settings.cloudBackup;

  // ---------- settings ----------

  void updateSettings(void Function(GlobalSettings s) edit) {
    edit(data.settings);
    _changed();
    if (_mirror) cloud.upsertSettings(data.settings);
  }

  Future<void> setCloudBackup(bool on) async {
    data.settings.cloudBackup = on;
    _changed();
    if (on) await cloud.pushAll(data);
  }

  // ---------- children ----------

  /// Creates a child with the eight starter routines and makes it active.
  ChildProfile addChild({
    required String alias,
    required String ageGroup,
    bool? lowMotion,
    bool softLighting = false,
    bool muteHighPitch = true,
    bool withTemplates = true,
  }) {
    final name = alias.trim().isEmpty ? 'Friend' : alias.trim();
    final child = ChildProfile(
      id: newId('child'),
      alias: name.length > 24 ? name.substring(0, 24) : name,
      ageGroup: ageGroup,
      sensory: SensoryProfile(
        // L16: calm motion by default for the youngest group.
        lowMotion: lowMotion ?? ageGroup == '2-4',
        softLighting: softLighting,
        muteHighPitch: muteHighPitch,
      ),
    );
    data.children.add(child);
    data.settings.activeChildId = child.id;
    final routines = withTemplates
        ? [for (final t in routineTemplates) t.build(child.id)]
        : <Routine>[];
    data.routines.addAll(routines);
    _changed();
    if (_mirror) {
      cloud.upsertSettings(data.settings);
      cloud.upsertChild(child);
      routines.forEach(cloud.upsertRoutine);
    }
    return child;
  }

  void updateChild(ChildProfile c) {
    c.updatedAt = DateTime.now();
    _changed();
    if (_mirror) cloud.upsertChild(c);
  }

  void setActiveChild(String id) {
    if (!data.children.any((c) => c.id == id)) return;
    updateSettings((s) => s.activeChildId = id);
  }

  void deleteChild(String id) {
    data.children.removeWhere((c) => c.id == id);
    data.routines.removeWhere((r) => r.childId == id);
    data.sessions.removeWhere((s) => s.childId == id);
    _repair();
    _changed();
    if (_mirror) {
      cloud.deleteChild(id);
      cloud.upsertSettings(data.settings);
    }
  }

  // ---------- routines ----------

  void upsertRoutine(Routine r) {
    r.updatedAt = DateTime.now();
    final i = data.routines.indexWhere((x) => x.id == r.id);
    if (i >= 0) {
      data.routines[i] = r;
    } else {
      data.routines.add(r);
    }
    _changed();
    if (_mirror) cloud.upsertRoutine(r);
  }

  void deleteRoutine(Routine r) {
    data.routines.removeWhere((x) => x.id == r.id);
    _changed();
    if (_mirror) cloud.deleteRoutine(r);
  }

  /// Clears every step so the routine can be run again.
  void resetRoutine(Routine r) {
    for (final s in r.steps) {
      s.isCompleted = false;
    }
    r.activeRunId = null;
    upsertRoutine(r);
  }

  /// Marks step [index] done. Returns true when that finished the routine.
  /// Each run is logged as one 'routine' session that grows as steps finish,
  /// which gives the dashboard its completion rate.
  bool completeStep(Routine r, int index) {
    if (index < 0 || index >= r.steps.length || r.steps[index].isCompleted) return false;
    r.steps[index].isCompleted = true;
    final now = DateTime.now();
    SensorySession? run;
    if (r.activeRunId != null) {
      for (final s in data.sessions) {
        if (s.id == r.activeRunId) run = s;
      }
    }
    if (run == null) {
      run = SensorySession(
        id: newId('sess'),
        childId: r.childId,
        mode: 'routine',
        start: now,
        routineId: r.id,
        routineTitle: r.title,
      );
      r.activeRunId = run.id;
      data.sessions.add(run);
    }
    run
      ..stepsDone = r.doneCount
      ..stepsTotal = r.steps.length
      ..durationSeconds = now.difference(run.start).inSeconds
      ..updatedAt = now;
    final finished = r.isFinished;
    if (finished) r.activeRunId = null;
    _trimSessions();
    upsertRoutine(r);
    if (_mirror) cloud.upsertSession(run);
    return finished;
  }

  // ---------- sessions ----------

  void logSession(SensorySession s) {
    s.updatedAt = DateTime.now();
    final i = data.sessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      data.sessions[i] = s;
    } else {
      data.sessions.add(s);
    }
    _trimSessions();
    _changed();
    if (_mirror) cloud.upsertSession(s);
  }

  void _trimSessions() {
    if (data.sessions.length > maxSessions) {
      data.sessions.sort((a, b) => a.start.compareTo(b.start));
      data.sessions.removeRange(0, data.sessions.length - maxSessions);
    }
  }

  // ---------- cloud merge / reset ----------

  /// Merges a cloud copy into the device: union by id, newest `updatedAt` wins.
  /// Local step photos are kept when the cloud copy of a routine wins.
  void mergeFrom(CloudSnapshot snap) {
    T? find<T>(List<T> list, bool Function(T) test) {
      for (final x in list) {
        if (test(x)) return x;
      }
      return null;
    }

    for (final c in snap.children) {
      final i = data.children.indexWhere((x) => x.id == c.id);
      if (i < 0) {
        data.children.add(c);
      } else if (c.updatedAt.isAfter(data.children[i].updatedAt)) {
        data.children[i] = c;
      }
    }
    for (final r in snap.routines) {
      final i = data.routines.indexWhere((x) => x.id == r.id);
      if (i < 0) {
        data.routines.add(r);
      } else if (r.updatedAt.isAfter(data.routines[i].updatedAt)) {
        final old = data.routines[i];
        for (final s in r.steps) {
          s.photoPath ??= find(old.steps, (o) => o.id == s.id)?.photoPath;
        }
        data.routines[i] = r;
      }
    }
    for (final s in snap.sessions) {
      final i = data.sessions.indexWhere((x) => x.id == s.id);
      if (i < 0) {
        data.sessions.add(s);
      } else if (s.updatedAt.isAfter(data.sessions[i].updatedAt)) {
        data.sessions[i] = s;
      }
    }
    _trimSessions();
    _repair();
    _changed();
  }

  /// Erases everything on this device (sign-out / account deletion).
  Future<void> wipe() async {
    for (final r in data.routines) {
      for (final s in r.steps) {
        final p = s.photoPath;
        if (p != null) {
          try {
            await File(p).delete();
          } catch (_) {}
        }
      }
    }
    data = AppData();
    _changed();
    await flush();
  }
}
