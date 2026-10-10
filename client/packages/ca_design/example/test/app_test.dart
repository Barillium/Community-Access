import 'dart:io';

import 'package:ca_design_example/app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Bildschirmbilder je Plattform: flutter test --update-goldens test/app_test.dart
Future<void> _fonts() async {
  final archivo = FontLoader('packages/ca_design/Archivo')
    ..addFont(
        rootBundle.load('packages/ca_design/fonts/Archivo[wdth,wght].ttf'));
  await archivo.load();
  final sdk = Platform.environment['FLUTTER_ROOT']!;
  for (final (family, file) in [
    ('MaterialIcons', 'material_fonts/MaterialIcons-Regular.otf'),
    ('CupertinoIcons', '../pkg/sky_engine/lib/_embedder.yaml'),
  ]) {
    final f = File('$sdk/bin/cache/artifacts/$file');
    if (!f.existsSync() || !file.endsWith('otf')) continue;
    final l = FontLoader(family)
      ..addFont(f.readAsBytes().then(ByteData.sublistView));
    await l.load();
  }
}

Future<void> _images(WidgetTester tester) => tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });

Future<void> _settle(WidgetTester tester) async {
  await _images(tester);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> Function(WidgetTester, Widget) _setUp(
        TargetPlatform platform, Size size, double top, double bottom,
        [double dpr = 3]) =>
    (tester, app) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.physicalSize = size * dpr;
      tester.view.devicePixelRatio = dpr;
      tester.view.padding =
          FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
      tester.view.viewPadding =
          FakeViewPadding(top: top * dpr, bottom: bottom * dpr);
      await tester.pumpWidget(app);
      await _settle(tester);
    };

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  debugDefaultTargetPlatformOverride = null;
  tester.view.reset();
}

Future<void> _openEvent(WidgetTester tester) async {
  final row = find.text('NACHT DER KLANGLANDSCHAFTEN');
  await tester.scrollUntilVisible(row, 300,
      scrollable: find.byType(Scrollable).first);
  await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -200));
  await _settle(tester);
  await tester.tap(row);
  await _settle(tester);
}

void main() {
  setUpAll(_fonts);
  const devices = {
    // Breite, Höhe, Abstand oben, Abstand unten (logische Punkte)
    TargetPlatform.iOS: ('ios', Size(393, 852), 59.0, 34.0),
    TargetPlatform.android: ('android', Size(412, 915), 24.0, 16.0),
  };

  for (final MapEntry(key: platform, value: (name, size, top, bottom))
      in devices.entries) {
    final setUp = _setUp(platform, size, top, bottom);
    const done = _done;

    for (final (tab, screen) in [
      (0, 'programm'),
      (2, 'zugang'),
      (3, 'konto')
    ]) {
      testWidgets('$name $screen', (tester) async {
        await setUp(tester, DemoApp(tab: tab));
        await expectLater(
            find.byType(DemoApp), matchesGoldenFile('app/$name-$screen.png'));
        // Was App Store und Play beim Prüfen der Barrierefreiheit ansehen.
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // textContrastGuideline misst Pixel und hält den Klebestreifen hinter der
        // Schrift für Hintergrund; Kontraste prüft test/ca_design_test.dart an den Tokens.
        await expectLater(
            tester,
            meetsGuideline(platform == TargetPlatform.iOS
                ? iOSTapTargetGuideline
                : androidTapTargetGuideline));
        await done(tester);
      });
    }

    testWidgets('$name merkliste wischen', (tester) async {
      await setUp(tester, const DemoApp(tab: 1));
      final g = await tester.startGesture(tester.getCenter(find
          .descendant(
              of: find.byType(MerklisteScreen),
              matching: find.text('LESUNG IM TREPPENHAUS'))
          .last));
      await g.moveBy(const Offset(-60, 0));
      await tester.pump();
      await g.moveBy(const Offset(-120, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
          find.byType(DemoApp), matchesGoldenFile('app/$name-merkliste.png'));
      await g.up();
      await done(tester);
    });

    testWidgets('$name event aktionen', (tester) async {
      await setUp(tester, const DemoApp());
      await _openEvent(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.byTooltip('Mehr'));
      await _settle(tester);
      await expectLater(
          find.byType(DemoApp), matchesGoldenFile('app/$name-event.png'));
      await done(tester);
    });
  }

  // Store-Bilder in Pflichtgrößen: App Store 6,9" (1320 × 2868),
  // Google Play 9:16 (1080 × 1920), dazu Android-Tablet quer und hoch.
  const store = [
    ('ios-69', TargetPlatform.iOS, Size(440, 956), 62.0, 34.0, 3.0),
    ('play-916', TargetPlatform.android, Size(360, 640), 24.0, 16.0, 3.0),
    ('tablet-quer', TargetPlatform.android, Size(1280, 800), 24.0, 16.0, 2.0),
    ('tablet-hoch', TargetPlatform.android, Size(800, 1280), 24.0, 16.0, 2.0),
  ];
  for (final (name, platform, size, top, bottom, dpr) in store) {
    final setUp = _setUp(platform, size, top, bottom, dpr);
    for (final (i, tab, screen) in [
      (1, 0, 'programm'),
      (3, 1, 'merkliste'),
      (4, 2, 'zugang')
    ]) {
      testWidgets('store $name $screen', (tester) async {
        await setUp(tester, DemoApp(tab: tab));
        await expectLater(find.byType(DemoApp),
            matchesGoldenFile('store/$name-$i-$screen.png'));
        await _done(tester);
      });
    }
    testWidgets('store $name event', (tester) async {
      await setUp(tester, const DemoApp());
      await _openEvent(tester);
      await expectLater(
          find.byType(DemoApp), matchesGoldenFile('store/$name-2-event.png'));
      await _done(tester);
    });
  }
}
