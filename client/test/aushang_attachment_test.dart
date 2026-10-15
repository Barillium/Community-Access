import 'package:community_access_client/program_views.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/aushang_motion.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/event_carousel.dart';
import 'package:community_access_client/event_editorial_view.dart';
import 'package:community_access_client/event_management_list.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Archivo',
    )..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))).load();
    await (FontLoader(
      'packages/ca_design/CaIcons',
    )..addFont(rootBundle.load('packages/ca_design/fonts/CaIcons.ttf'))).load();
  });
  Widget host(
    Widget child, {
    bool reduced = false,
    bool dark = false,
    TargetPlatform platform = TargetPlatform.android,
  }) => MaterialApp(
    theme: AccessDesign.theme(dark: dark).copyWith(platform: platform),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('attendance answers survive a responsive column change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: ProgramDetailPage(
          api: _AttendanceFixture(),
          kind: 'events',
          id: 'one',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byType(TextFormField);
    expect(field, findsOneWidget);
    await tester.enterText(field, 'Synthetische Antwort bleibt erhalten');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(field).controller!.text,
      'Synthetische Antwort bleibt erhalten',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('poster only changes manually and retains the selected event', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(EventCarousel(events: DiscoveryFixture().events, onOpen: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Demo Ambientabend'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Demo Ambientabend'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Nächste Veranstaltung'));
    await tester.tap(find.byTooltip('Nächste Veranstaltung'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Secret Night'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Demo Secret Night'), findsOneWidget);
    expect(find.byTooltip('Plakatwechsel starten'), findsNothing);
    expect(find.byTooltip('Plakatwechsel pausieren'), findsNothing);
    await tester.ensureVisible(find.byTooltip('Vorherige Veranstaltung'));
    await tester.tap(find.byTooltip('Vorherige Veranstaltung'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Ambientabend'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reduced motion never rotates and manual selection still works', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        EventCarousel(events: DiscoveryFixture().events, onOpen: (_) {}),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Demo Ambientabend'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Nächste Veranstaltung'));
    await tester.tap(find.byTooltip('Nächste Veranstaltung'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Secret Night'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'poster paste clips rather than resizing, and reduced motion only fades',
    (tester) async {
      for (final reduced in [false, true]) {
        await tester.pumpWidget(
          host(
            AccessPaste(
              key: ValueKey(reduced),
              child: const SizedBox(width: 200, height: 100),
            ),
            reduced: reduced,
          ),
        );
        expect(tester.getSize(find.byType(AccessPaste)), const Size(200, 100));
        if (reduced) {
          expect(find.byType(Opacity), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(AccessPaste),
              matching: find.byType(Transform),
            ),
            findsNothing,
          );
        }
        await tester.pumpAndSettle();
        if (!reduced) {
          final clip = tester.widget<ClipRect>(find.byType(ClipRect).last);
          expect(
            clip.clipper!.getClip(const Size(200, 100)),
            const Rect.fromLTWH(0, 0, 200, 100),
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('touch and reduced motion never tilt a flyer', (tester) async {
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        host(
          const AccessFlyerHover(child: SizedBox(width: 120, height: 120)),
          reduced: reduced,
        ),
      );
      await tester.pumpAndSettle();
      final touch = await tester.startGesture(
        tester.getCenter(find.byType(AccessFlyerHover)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      final transforms = tester.widgetList<Transform>(
        find.descendant(
          of: find.byType(AccessFlyerHover),
          matching: find.byType(Transform),
        ),
      );
      for (final transform in transforms) {
        expect(transform.transform, Matrix4.identity());
      }
      await touch.up();
    }
  });
  testWidgets(
    'title preserves text, line breaks and accessible name in both motion modes',
    (tester) async {
      for (final reduced in [false, true]) {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          host(
            AccessKineticTitle(
              'WALDFUNK',
              key: ValueKey(reduced),
              style: const TextStyle(fontSize: 72),
            ),
            reduced: reduced,
          ),
        );
        expect(find.text('WALDFUNK'), findsOneWidget);
        expect(find.bySemanticsLabel('WALDFUNK'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      }
    },
  );
  testWidgets('supplied action keeps labeled 48px targets in both platforms', (
    tester,
  ) async {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          AccessAction(onPressed: () {}, child: const Text('Event ansehen')),
          platform: platform,
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    }
  });
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final dark in [false, true]) {
      for (final width in [390.0, 1280.0]) {
        testWidgets('attachment layouts fit $platform dark=$dark width=$width', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final event = DiscoveryFixture().events.first;
          final screens = <String, Widget>{
            'programm': EventCarousel(
              events: DiscoveryFixture().events,
              onOpen: (_) {},
            ),
            'event': Padding(
              padding: const EdgeInsets.all(16),
              child: EventEditorialView(
                event: event,
                participation: const Text('Synthetischer Teilnahmestand'),
              ),
            ),
            'verwaltung': Padding(
              padding: const EdgeInsets.all(16),
              child: EventManagementList(
                events: [event],
                busy: false,
                onEdit: (_) {},
                onDuplicate: (_) {},
                onNext: (_) {},
                onPreview: (_) {},
              ),
            ),
          };
          for (final screen in screens.entries) {
            final boundary = GlobalKey();
            await tester.pumpWidget(
              host(
                RepaintBoundary(key: boundary, child: screen.value),
                reduced: true,
                dark: dark,
                platform: platform,
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final output = Platform.environment['CA_DESIGN_PROOF_DIR'];
            if (output != null) {
              await tester.runAsync(() async {
                final render =
                    boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary;
                final picture = await render.toImage();
                final data = await picture.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final dir = Directory(output)..createSync(recursive: true);
                await File(
                  '${dir.path}/${screen.key}-${platform.name}-${dark ? 'dunkel' : 'hell'}-${width.toInt()}.png',
                ).writeAsBytes(data!.buffer.asUint8List());
                picture.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox());
          }
        });
      }
    }
  }
}

class _AttendanceFixture extends DiscoveryFixture {
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'events/one') return {...events.first, 'signed_in': true};
    if (path == 'events/one/access') {
      return {
        'signed_in': true,
        'can_request': true,
        'method': 'form',
        'form_version': 1,
        'form': [
          {'key': 'note', 'label': 'Synthetische Antwort'},
        ],
      };
    }
    return super.directory(path, query: query, body: body);
  }
}
