import 'package:community_access_client/flyer_icons.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_symbols.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/public_home_page.dart';

import 'directory_widget_test.dart' show DirectoryFixture;

void main() {
  setUpAll(() async {
    final archivo = FontLoader('Archivo')
      ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'));
    await archivo.load();
  });
  testWidgets('dimmed icons omit the decorative accent and keep their label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: const IconTheme(
          data: IconThemeData(color: Colors.black, opacity: .38),
          child: AccessIcon(Icons.lock, semanticLabel: 'Gesperrt'),
        ),
      ),
    );
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<FlyerIconPainter>()
        .single;
    expect(painter.symbol, AccessSymbol.lock);
    expect(painter.color.a, closeTo(.38, .01));
    expect(painter.color.r, 0);
    expect(painter.color.g, 0);
    expect(painter.color.b, 0);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Gesperrt'), findsOneWidget);
    semantics.dispose();
  });

  test('every symbol remains visible without its decorative accent', () async {
    for (final symbol in AccessSymbol.values) {
      for (final size in [16, 20, 24, 32]) {
        final recorder = ui.PictureRecorder();
        AccessSymbolPainter(
          symbol,
          ink: Colors.black,
          accent: null,
        ).paint(Canvas(recorder), Size.square(size.toDouble()));
        final picture = recorder.endRecording();
        final image = await picture.toImage(size, size);
        final data = await image.toByteData();
        var visible = 0;
        for (var i = 0; i < data!.lengthInBytes; i += 4) {
          if (data.getUint8(i + 3) == 0) continue;
          visible++;
          expect(data.getUint8(i), 0, reason: '$symbol at $size');
          expect(data.getUint8(i + 1), 0, reason: '$symbol at $size');
          expect(data.getUint8(i + 2), 0, reason: '$symbol at $size');
        }
        expect(visible, greaterThan(4), reason: '$symbol at $size');
        image.dispose();
        picture.dispose();
      }
    }
    final output = Platform.environment['CA_SYMBOL_PROOF_PATH'];
    if (output != null) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const width = 920;
      final height = ((AccessSymbol.values.length + 7) ~/ 8) * 100;
      canvas.drawColor(Colors.white, BlendMode.src);
      for (var i = 0; i < AccessSymbol.values.length; i++) {
        canvas.save();
        canvas.translate((i % 8) * 115.0, (i ~/ 8) * 100.0);
        for (var variant = 0; variant < 2; variant++) {
          canvas.save();
          canvas.translate(12.0 + variant * 48, 12);
          AccessSymbolPainter(
            AccessSymbol.values[i],
            ink: AccessDesign.ink,
            accent: variant == 1 ? AccessDesign.accent : null,
            active: variant == 1,
          ).paint(canvas, const Size.square(32));
          canvas.restore();
        }
        final text = TextPainter(
          text: TextSpan(
            text: AccessSymbol.values[i].name,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 11,
              fontFamily: 'Archivo',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 112);
        text.paint(canvas, const Offset(8, 58));
        canvas.restore();
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('mobile menu supports selection and Escape in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(dark: brightness == Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: PublicHomePage(
            directoryApi: DirectoryFixture(),
            accountBuilder: (_) => const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final menu = find.byTooltip('Menü');
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final community = find.ancestor(
        of: find.text('Communities'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      );
      await tester.ensureVisible(community);
      expect(tester.getSize(community).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(community).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(community).right, lessThanOrEqualTo(320));
      await tester.tap(community);
      await tester.pumpAndSettle();
      expect(find.text('Öffentliche Communities'), findsOneWidget);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        findsNothing,
      );
      final icon = tester.widget<AccessIcon>(
        find.descendant(of: menu, matching: find.byType(AccessIcon)),
      );
      expect(icon.icon, Icons.menu);
      expect(tester.takeException(), isNull);
    });
  }
}
