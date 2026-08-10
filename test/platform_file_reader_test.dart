import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ona_net/core/utils/platform_file_reader.dart';

void main() {
  test('reads a path-backed picked file without in-memory bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'onanet-file-reader-',
    );
    addTearDown(() => directory.delete(recursive: true));

    final source = File('${directory.path}/logo.png');
    await source.writeAsBytes(const [137, 80, 78, 71]);
    final pickedFile = PlatformFile(
      name: 'logo.png',
      size: await source.length(),
      path: source.path,
    );

    expect(await readPlatformFileBytes(pickedFile), [137, 80, 78, 71]);
  });
}
