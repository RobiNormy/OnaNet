import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Reads a picked file whether the platform returned bytes, a cached path, or
/// a web blob URL.
Future<Uint8List?> readPlatformFileBytes(PlatformFile file) async {
  try {
    return await file.xFile.readAsBytes();
  } catch (_) {
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
