import 'dart:io';

import 'package:ca_design_example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Bildschirmbilder der Bausteinübersicht: flutter test --update-goldens test/screens_test.dart
Future<void> _fonts() async {
  final archivo = FontLoader('packages/ca_design/Archivo')
    ..addFont(
        rootBundle.load('packages/ca_design/fonts/Archivo[wdth,wght].ttf'));
  await archivo.load();
  final sdk = Platform.environment['FLUTTER_ROOT']!;
  final icons = FontLoader('MaterialIcons')
    ..addFont(File(
            '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then((b) => ByteData.sublistView(b)));
  await icons.load();
}

void main() {
  setUpAll(_fonts);
  for (final (name, platform, size, dark) in [
    ('ios-hell', TargetPlatform.iOS, const Size(393, 2160), false),
    ('android-dunkel', TargetPlatform.android, const Size(412, 2160), true),
  ]) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      tester.platformDispatcher.platformBrightnessTestValue =
          dark ? Brightness.dark : Brightness.light;
      await tester.pumpWidget(const Gallery());
      await tester.runAsync(() async {
        for (final e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
          find.byType(Gallery), matchesGoldenFile('screens/$name.png'));
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
  }
}
