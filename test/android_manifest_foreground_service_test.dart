import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifestFile = File('android/app/src/main/AndroidManifest.xml');

  test('foreground task service does not request location service type', () {
    final manifest = manifestFile.readAsStringSync();

    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(
      manifest,
      isNot(contains('android:foregroundServiceType="dataSync|location"')),
    );
    expect(
      manifest,
      isNot(contains('android.permission.FOREGROUND_SERVICE_LOCATION')),
    );
  });
}
