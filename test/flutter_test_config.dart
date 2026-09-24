import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load the app's real font so widget tests measure text like a phone does
/// (by default tests use a font where every glyph is a full-width square).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader('Andika');
  for (final f in ['Andika-Regular.ttf', 'Andika-Bold.ttf']) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  }
  await loader.load();
  await testMain();
}
