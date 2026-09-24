// Sound output: one looping ambience plus short, soft effects.
//
// All files are pre-filtered at build time (scripts/make_audio.py, L11); the
// child's cutoff picks the variant. Every start and stop fades, so nothing
// ever begins or ends abruptly.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

abstract class SoundService {
  /// Global mute (PDD: one-tap mute on every screen) and master volume.
  void configure({required bool muted, required double volume});

  /// Starts (or switches to) a looping sound, e.g. 'rain' with variant '4k'.
  Future<void> playLoop(String name, String variant, {double level = 1.0});

  /// Fades the loop out over [fade] and stops it.
  Future<void> stopLoop({Duration fade = const Duration(milliseconds: 800)});

  String? get currentLoop;

  /// Loop volume relative to master (used by the sleep fade), 0..1.
  void setLoopLevel(double level);

  Future<void> playSfx(String name);

  Future<void> dispose();
}

/// Silent implementation for tests and for when audio fails to start.
class SilentSoundService implements SoundService {
  String? _loop;
  final played = <String>[];
  @override
  void configure({required bool muted, required double volume}) {}
  @override
  Future<void> playLoop(String name, String variant, {double level = 1.0}) async {
    _loop = name;
    played.add('loop:$name:$variant');
  }

  @override
  Future<void> stopLoop({Duration fade = const Duration(milliseconds: 800)}) async => _loop = null;
  @override
  String? get currentLoop => _loop;
  @override
  void setLoopLevel(double level) {}
  @override
  Future<void> playSfx(String name) async => played.add('sfx:$name');
  @override
  Future<void> dispose() async {}
}

class JustAudioSoundService implements SoundService {
  final _loop = AudioPlayer();
  final _sfx = [AudioPlayer(), AudioPlayer()];
  int _nextSfx = 0;
  bool _muted = false;
  double _master = 0.8;
  double _loopLevel = 1.0;
  String? _loopName;
  String? _loopAsset;
  Timer? _fadeTimer;

  @override
  String? get currentLoop => _loopName;

  double get _loopTarget => _muted ? 0 : _master * _loopLevel;

  @override
  void configure({required bool muted, required double volume}) {
    _muted = muted;
    _master = volume;
    if (_fadeTimer == null && _loopName != null) {
      _loop.setVolume(_loopTarget);
    }
    for (final p in _sfx) {
      p.setVolume(_muted ? 0 : _master);
    }
  }

  Future<void> _fadeTo(double target, Duration d) {
    _fadeTimer?.cancel();
    final done = Completer<void>();
    final start = _loop.volume;
    const tick = Duration(milliseconds: 40);
    final steps = (d.inMilliseconds / tick.inMilliseconds).ceil().clamp(1, 1000);
    var i = 0;
    _fadeTimer = Timer.periodic(tick, (t) {
      i++;
      _loop.setVolume(start + (target - start) * (i / steps));
      if (i >= steps) {
        t.cancel();
        _fadeTimer = null;
        done.complete();
      }
    });
    return done.future;
  }

  @override
  Future<void> playLoop(String name, String variant, {double level = 1.0}) async {
    final asset = 'assets/audio/loops/${name}_$variant.wav';
    _loopLevel = level;
    if (asset == _loopAsset && _loop.playing) {
      await _fadeTo(_loopTarget, const Duration(milliseconds: 400));
      return;
    }
    try {
      if (_loop.playing) await stopLoop(fade: const Duration(milliseconds: 500));
      _loopName = name;
      _loopAsset = asset;
      await _loop.setAsset(asset);
      await _loop.setLoopMode(LoopMode.one);
      await _loop.setVolume(0);
      unawaited(_loop.play());
      await _fadeTo(_loopTarget, const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('playLoop failed: $e');
    }
  }

  @override
  Future<void> stopLoop({Duration fade = const Duration(milliseconds: 800)}) async {
    if (_loopName == null) return;
    _loopName = null;
    try {
      await _fadeTo(0, fade);
      await _loop.stop();
    } catch (e) {
      debugPrint('stopLoop failed: $e');
    }
    _loopAsset = null;
  }

  @override
  void setLoopLevel(double level) {
    _loopLevel = level.clamp(0.0, 1.0);
    if (_fadeTimer == null && _loopName != null) _loop.setVolume(_loopTarget);
  }

  @override
  Future<void> playSfx(String name) async {
    if (_muted) return;
    final p = _sfx[_nextSfx];
    _nextSfx = (_nextSfx + 1) % _sfx.length;
    try {
      await p.setAsset('assets/audio/sfx/$name.wav');
      await p.setVolume(_master);
      await p.seek(Duration.zero);
      unawaited(p.play());
    } catch (e) {
      debugPrint('playSfx failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    _fadeTimer?.cancel();
    await _loop.dispose();
    for (final p in _sfx) {
      await p.dispose();
    }
  }
}
