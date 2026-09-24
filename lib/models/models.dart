// Data model for Sensory SafeScape.
//
// Everything is plain JSON so the same maps are written to the device file
// (the source of truth) and mirrored to Firestore under users/{uid}/...

import 'dart:math';

final _rand = Random();

/// Short, sortable, collision-safe id (time + random).
String newId(String prefix) {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final r = _rand.nextInt(1 << 32).toRadixString(36).padLeft(7, '0');
  return '${prefix}_$t$r';
}

String _iso(DateTime d) => d.toUtc().toIso8601String();
DateTime _date(Object? v) =>
    v is String ? (DateTime.tryParse(v) ?? DateTime.now()) : DateTime.now();
double _num(Object? v, double fallback) => v is num ? v.toDouble() : fallback;
bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;
String _str(Object? v, String fallback) => v is String ? v : fallback;

const ageGroups = ['2-4', '5-7', '8-10'];
const palettes = ['lavender', 'mint', 'sand', 'blue'];
const soundNames = ['hum', 'rain', 'ocean', 'marimba'];

/// Audio cutoffs in Hz, matching the rendered variants in assets/audio/loops.
const audioCutoffs = [6000, 4000, 2500];

class SensoryProfile {
  bool lowMotion;
  bool softLighting;
  bool muteHighPitch;
  int audioCutoffHz;
  double particleDensity; // 0.2 .. 1.0
  double motionSpeed; // 0.3 .. 1.0 (Low Motion halves it again)
  double colorTemperature; // 0 (neutral) .. 1 (warmest overlay)
  bool hapticFeedback;
  bool breathingRing;
  bool canvasSound;
  String palette;

  SensoryProfile({
    this.lowMotion = false,
    this.softLighting = false,
    this.muteHighPitch = true,
    this.audioCutoffHz = 6000,
    this.particleDensity = 0.6,
    this.motionSpeed = 0.7,
    this.colorTemperature = 0.5,
    this.hapticFeedback = false,
    this.breathingRing = true,
    this.canvasSound = true,
    this.palette = 'lavender',
  });

  /// The cutoff actually used: "Mute high pitch" caps it at 4 kHz.
  int get effectiveCutoffHz =>
      muteHighPitch ? min(audioCutoffHz, 4000) : audioCutoffHz;

  /// Asset suffix for the rendered loop variant.
  String get audioVariant => switch (effectiveCutoffHz) {
    >= 6000 => '6k',
    >= 4000 => '4k',
    _ => '2k5',
  };

  /// Overall motion multiplier for animations.
  double get motionFactor => motionSpeed * (lowMotion ? 0.5 : 1.0);

  Map<String, dynamic> toJson() => {
    'low_motion_mode': lowMotion,
    'soft_lighting': softLighting,
    'mute_high_pitch': muteHighPitch,
    'audio_cutoff_hz': audioCutoffHz,
    'particle_density': particleDensity,
    'motion_speed': motionSpeed,
    'color_temperature': colorTemperature,
    'haptic_feedback_enabled': hapticFeedback,
    'breathing_ring': breathingRing,
    'canvas_sound': canvasSound,
    'palette': palette,
  };

  factory SensoryProfile.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    final cutoff = j['audio_cutoff_hz'];
    return SensoryProfile(
      lowMotion: _bool(j['low_motion_mode'], false),
      softLighting: _bool(j['soft_lighting'], false),
      muteHighPitch: _bool(j['mute_high_pitch'], true),
      audioCutoffHz: cutoff is num && audioCutoffs.contains(cutoff.toInt())
          ? cutoff.toInt()
          : 6000,
      particleDensity: _num(j['particle_density'], 0.6).clamp(0.2, 1.0),
      motionSpeed: _num(j['motion_speed'], 0.7).clamp(0.3, 1.0),
      colorTemperature: _num(j['color_temperature'], 0.5).clamp(0.0, 1.0),
      hapticFeedback: _bool(j['haptic_feedback_enabled'], false),
      breathingRing: _bool(j['breathing_ring'], true),
      canvasSound: _bool(j['canvas_sound'], true),
      palette: palettes.contains(j['palette']) ? j['palette'] as String : 'lavender',
    );
  }

  SensoryProfile copy() => SensoryProfile.fromJson(toJson());
}

class ChildProfile {
  final String id;
  String alias;
  String ageGroup;
  String avatar;
  SensoryProfile sensory;
  final DateTime createdAt;
  DateTime updatedAt;

  ChildProfile({
    required this.id,
    required this.alias,
    required this.ageGroup,
    this.avatar = 'turtle_sammy',
    SensoryProfile? sensory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : sensory = sensory ?? SensoryProfile(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'alias_name': alias,
    'age_group': ageGroup,
    'avatar_type': avatar,
    'sensory_profile': sensory.toJson(),
    'created_at': _iso(createdAt),
    'updated_at': _iso(updatedAt),
  };

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
    id: _str(j['id'], newId('child')),
    alias: _str(j['alias_name'], 'Friend'),
    ageGroup: ageGroups.contains(j['age_group']) ? j['age_group'] as String : '5-7',
    avatar: _str(j['avatar_type'], 'turtle_sammy'),
    sensory: SensoryProfile.fromJson(
      (j['sensory_profile'] as Map?)?.cast<String, dynamic>(),
    ),
    createdAt: _date(j['created_at']),
    updatedAt: _date(j['updated_at']),
  );
}

class RoutineStep {
  final String id;
  String title;
  String iconKey;
  String story; // optional micro-story read aloud
  String? photoPath; // local only; never uploaded (L6)
  bool isCompleted;

  RoutineStep({
    required this.id,
    required this.title,
    required this.iconKey,
    this.story = '',
    this.photoPath,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson({bool forCloud = false}) => {
    'id': id,
    'title': title,
    'icon_key': iconKey,
    'story': story,
    if (!forCloud && photoPath != null) 'photo_path': photoPath,
    'is_completed': isCompleted,
  };

  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
    id: _str(j['id'], newId('step')),
    title: _str(j['title'], 'Step'),
    iconKey: _str(j['icon_key'], 'star'),
    story: _str(j['story'], ''),
    photoPath: j['photo_path'] is String ? j['photo_path'] as String : null,
    isCompleted: _bool(j['is_completed'], false),
  );
}

class Routine {
  final String id;
  final String childId;
  String title;
  String iconKey;
  List<RoutineStep> steps;
  String? activeRunId; // session id of the run in progress
  final DateTime createdAt;
  DateTime updatedAt;

  Routine({
    required this.id,
    required this.childId,
    required this.title,
    required this.iconKey,
    required this.steps,
    this.activeRunId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  int get doneCount => steps.where((s) => s.isCompleted).length;
  bool get isFinished => steps.isNotEmpty && doneCount == steps.length;

  /// Index of the first unfinished step, or -1 when all are done.
  int get currentIndex => steps.indexWhere((s) => !s.isCompleted);

  Map<String, dynamic> toJson({bool forCloud = false}) => {
    'routine_id': id,
    'child_id': childId,
    'title': title,
    'icon_key': iconKey,
    'steps': [
      for (var i = 0; i < steps.length; i++)
        {'step_order': i + 1, ...steps[i].toJson(forCloud: forCloud)},
    ],
    'active_run_id': activeRunId,
    'created_at': _iso(createdAt),
    'updated_at': _iso(updatedAt),
  };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
    id: _str(j['routine_id'], newId('routine')),
    childId: _str(j['child_id'], ''),
    title: _str(j['title'], 'Routine'),
    iconKey: _str(j['icon_key'], 'star'),
    steps: [
      for (final s in (j['steps'] is List ? j['steps'] as List : const []))
        if (s is Map) RoutineStep.fromJson(s.cast<String, dynamic>()),
    ],
    activeRunId: j['active_run_id'] is String ? j['active_run_id'] as String : null,
    createdAt: _date(j['created_at']),
    updatedAt: _date(j['updated_at']),
  );

  Routine copyFor(String newChildId) => Routine(
    id: newId('routine'),
    childId: newChildId,
    title: title,
    iconKey: iconKey,
    steps: [
      for (final s in steps)
        RoutineStep(
          id: newId('step'),
          title: s.title,
          iconKey: s.iconKey,
          story: s.story,
          photoPath: s.photoPath,
        ),
    ],
  );
}

/// One use of a mode: a Flow Canvas visit, a sound played, a routine run or a
/// wait timer. Only durations and choices are stored, never raw touches.
class SensorySession {
  final String id;
  final String childId;
  final String mode; // flow_canvas | sounds | routine | wait_timer
  final DateTime start;
  int durationSeconds;
  String? palette;
  String? sound;
  String? touchRhythm; // slow_rhythmic | steady | busy
  String? routineId;
  String? routineTitle;
  int stepsDone;
  int stepsTotal;
  DateTime updatedAt;

  SensorySession({
    required this.id,
    required this.childId,
    required this.mode,
    required this.start,
    this.durationSeconds = 0,
    this.palette,
    this.sound,
    this.touchRhythm,
    this.routineId,
    this.routineTitle,
    this.stepsDone = 0,
    this.stepsTotal = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isCalming => mode == 'flow_canvas' || mode == 'sounds';

  Map<String, dynamic> toJson() => {
    'session_id': id,
    'child_id': childId,
    'mode_used': mode,
    'start_time': _iso(start),
    'duration_seconds': durationSeconds,
    if (palette != null) 'preset_applied': palette,
    if (sound != null) 'sound': sound,
    if (touchRhythm != null) 'avg_touch_frequency': touchRhythm,
    if (routineId != null) 'routine_id': routineId,
    if (routineTitle != null) 'routine_title': routineTitle,
    if (mode == 'routine') 'steps_done': stepsDone,
    if (mode == 'routine') 'steps_total': stepsTotal,
    'updated_at': _iso(updatedAt),
  };

  factory SensorySession.fromJson(Map<String, dynamic> j) => SensorySession(
    id: _str(j['session_id'], newId('sess')),
    childId: _str(j['child_id'], ''),
    mode: _str(j['mode_used'], 'flow_canvas'),
    start: _date(j['start_time']),
    durationSeconds: _num(j['duration_seconds'], 0).toInt(),
    palette: j['preset_applied'] as String?,
    sound: j['sound'] as String?,
    touchRhythm: j['avg_touch_frequency'] as String?,
    routineId: j['routine_id'] as String?,
    routineTitle: j['routine_title'] as String?,
    stepsDone: _num(j['steps_done'], 0).toInt(),
    stepsTotal: _num(j['steps_total'], 0).toInt(),
    updatedAt: _date(j['updated_at']),
  );
}

class GlobalSettings {
  bool audioMuted;
  double masterVolume;
  bool cloudBackup;
  bool speakSteps;
  String? activeChildId;

  GlobalSettings({
    this.audioMuted = false,
    this.masterVolume = 0.8,
    this.cloudBackup = true,
    this.speakSteps = true,
    this.activeChildId,
  });

  Map<String, dynamic> toJson() => {
    'audio_muted': audioMuted,
    'master_volume': masterVolume,
    'cloud_backup': cloudBackup,
    'speak_steps': speakSteps,
    'parent_gate_type': 'multiplication',
    'active_child_id': activeChildId,
  };

  factory GlobalSettings.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return GlobalSettings(
      audioMuted: _bool(j['audio_muted'], false),
      masterVolume: _num(j['master_volume'], 0.8).clamp(0.0, 1.0),
      cloudBackup: _bool(j['cloud_backup'], true),
      speakSteps: _bool(j['speak_steps'], true),
      activeChildId: j['active_child_id'] as String?,
    );
  }
}

/// Everything the app stores on the device.
class AppData {
  GlobalSettings settings;
  List<ChildProfile> children;
  List<Routine> routines;
  List<SensorySession> sessions;

  AppData({
    GlobalSettings? settings,
    List<ChildProfile>? children,
    List<Routine>? routines,
    List<SensorySession>? sessions,
  }) : settings = settings ?? GlobalSettings(),
       children = children ?? [],
       routines = routines ?? [],
       sessions = sessions ?? [];

  Map<String, dynamic> toJson() => {
    'version': 1,
    'global_settings': settings.toJson(),
    'children': [for (final c in children) c.toJson()],
    'visual_routines': [for (final r in routines) r.toJson()],
    'sensory_sessions': [for (final s in sessions) s.toJson()],
  };

  factory AppData.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) => [
      for (final e in (j[key] is List ? j[key] as List : const []))
        if (e is Map) f(e.cast<String, dynamic>()),
    ];
    return AppData(
      settings: GlobalSettings.fromJson(
        (j['global_settings'] as Map?)?.cast<String, dynamic>(),
      ),
      children: list('children', ChildProfile.fromJson),
      routines: list('visual_routines', Routine.fromJson),
      sessions: list('sensory_sessions', SensorySession.fromJson),
    );
  }
}
