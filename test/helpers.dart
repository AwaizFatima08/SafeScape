import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safescape/app.dart';
import 'package:safescape/core/learning.dart';
import 'package:safescape/services/audio.dart';
import 'package:safescape/services/cloud_sync.dart';
import 'package:safescape/services/speech.dart';
import 'package:safescape/services/store.dart';
import 'package:safescape/state/providers.dart';

class TestEnv {
  final Directory dir;
  final AppStore store;
  final SilentSoundService sound;
  final SilentSpeech speech;
  final CloudSync cloud;
  TestEnv(this.dir, this.store, this.sound, this.speech, this.cloud);

  Widget app() => ProviderScope(
    overrides: [
      storeProvider.overrideWith((ref) => store),
      cloudProvider.overrideWith((ref) => cloud),
      soundProvider.overrideWithValue(sound),
      speechProvider.overrideWithValue(speech),
      learningProvider.overrideWithValue(testLearning),
    ],
    child: const SafeScapeApp(),
  );
}

Future<TestEnv> makeEnv({CloudSync? cloud}) async {
  final dir = await Directory.systemTemp.createTemp('safescape_test');
  final c = cloud ?? OfflineCloudSync();
  final store = await AppStore.load(File('${dir.path}/safescape.json'), c);
  return TestEnv(dir, store, SilentSoundService(), SilentSpeech(), c);
}

/// The real lesson and story content, read straight from the asset files.
final testLearning = LearningContent.parse(
  File('assets/content/lessons.json').readAsStringSync(),
  File('assets/content/stories.json').readAsStringSync(),
);
