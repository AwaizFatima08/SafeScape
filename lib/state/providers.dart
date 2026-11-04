import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/learning.dart';
import '../services/audio.dart';
import '../services/cloud_sync.dart';
import '../services/speech.dart';
import '../services/store.dart';

// All are overridden in main() (and in tests) with real instances.
final storeProvider = ChangeNotifierProvider<AppStore>((ref) => throw UnimplementedError());
final cloudProvider = ChangeNotifierProvider<CloudSync>((ref) => throw UnimplementedError());
final soundProvider = Provider<SoundService>((ref) => throw UnimplementedError());
final speechProvider = Provider<Speech>((ref) => throw UnimplementedError());

/// Learn with Sammy chapters and built-in Picture Stories, loaded once at
/// start-up from assets/content (empty if the files can't be read).
final learningProvider = Provider<LearningContent>((ref) => LearningContent.empty);
