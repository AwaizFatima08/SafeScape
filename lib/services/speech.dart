// Slow, calm text-to-speech for step titles and micro-stories (L12).

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class Speech {
  Future<void> say(String text);
  Future<void> stop();
}

class SilentSpeech implements Speech {
  final spoken = <String>[];
  @override
  Future<void> say(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

class DeviceSpeech implements Speech {
  final _tts = FlutterTts();
  bool _ready = false;
  bool Function() isEnabled;

  DeviceSpeech({required this.isEnabled});

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(0.9);
      await _tts.awaitSpeakCompletion(false);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  @override
  Future<void> say(String text) async {
    if (!isEnabled() || text.trim().isEmpty) return;
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
