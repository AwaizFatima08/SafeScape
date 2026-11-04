// Picking a photo for a routine step or a story page. The photo is copied
// into the app's private folder and never leaves the device (§0 L6).

import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Lets the grown-up take or choose a photo; returns the private copy's path,
/// or null if they cancelled. Throws if the photo couldn't be saved.
Future<String?> pickLocalPhoto(ImageSource source) async {
  final x = await ImagePicker().pickImage(source: source, maxWidth: 900, maxHeight: 900, imageQuality: 82);
  if (x == null) return null;
  final dir = await getApplicationSupportDirectory();
  final folder = Directory('${dir.path}/photos');
  await folder.create(recursive: true);
  final dest = File('${folder.path}/${newId('photo')}.jpg');
  await File(x.path).copy(dest.path);
  return dest.path;
}
