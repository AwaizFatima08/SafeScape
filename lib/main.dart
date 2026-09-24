import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/audio.dart';
import 'services/cloud_sync.dart';
import 'services/speech.dart';
import 'services/store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    systemNavigationBarColor: Color(0xFF12131C),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  CloudSync cloud;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
    cloud = FirebaseCloudSync(auth: FirebaseAuth.instance, db: FirebaseFirestore.instance);
  } catch (e) {
    debugPrint('Firebase unavailable, running offline: $e');
    cloud = OfflineCloudSync();
  }

  final dir = await getApplicationSupportDirectory();
  final store = await AppStore.load(File('${dir.path}/safescape.json'), cloud);

  SoundService sound;
  try {
    sound = JustAudioSoundService();
  } catch (e) {
    sound = SilentSoundService();
  }
  sound.configure(muted: store.settings.audioMuted, volume: store.settings.masterVolume);
  final speech = DeviceSpeech(isEnabled: () => store.settings.speakSteps && !store.settings.audioMuted);

  // Silent background sign-in; the app never waits for it (L3).
  if (store.settings.cloudBackup && store.onboarded) {
    cloud.ensureSignedIn().then((_) {
      if (cloud.signedIn) cloud.upsertSettings(store.settings);
    });
  }

  runApp(ProviderScope(
    overrides: [
      storeProvider.overrideWith((ref) => store),
      cloudProvider.overrideWith((ref) => cloud),
      soundProvider.overrideWithValue(sound),
      speechProvider.overrideWithValue(speech),
    ],
    child: const SafeScapeApp(),
  ));
}
