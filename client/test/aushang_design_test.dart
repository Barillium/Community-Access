import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:community_access_client/appearance_scope.dart';
import 'package:community_access_client/aushang_tokens.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/event_carousel.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/public_home_page.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Exercise the real variable font geometry instead of test-only Ahem.
    final archivo = FontLoader('Archivo')
      ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Archivo-Italic-Variable.ttf'));
    await archivo.load();
  });

  test('visibility badges require explicit server visibility', () {
    expect(eventAccessLabel({'access_mode': 'private'}), 'Mit Zugang');
    expect(eventAccessLabel({'access_mode': 'semi_public'}), 'Semi-öffentlich');
    expect(eventAccessLabel({'is_public': true}), 'Öffentlich');
    expect(eventAccessLabel({}), isEmpty);
  });

  testWidgets('compact poster keeps a fitted Archivo word on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const sourceTitle = 'Demo mit geschütztem Ort';
    final title = sourceTitle.toUpperCase();
    final fixture = DiscoveryFixture();
    fixture.events.first['title'] = sourceTitle;
    await tester.pumpWidget(
      CommunityAccessApp(api: fixture, authOnly: true, showPublicHome: true),
    );
    await tester.pumpAndSettle();
    final posterText = find.descendant(
      of: find.byType(EventCarousel),
      matching: find.text(title),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: posterText, matching: find.byType(RichText)),
    );
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: title.indexOf('GESCHÜTZTEM'),
        extentOffset: title.indexOf(' ORT'),
      ),
    );
    expect(
      boxes,
      hasLength(1),
      reason: 'The fitted word must not break internally.',
    );
    expect(tester.takeException(), isNull);
  });

  for (final width in [960.0, 1280.0, 1440.0]) {
    testWidgets('hero columns align without overlap at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = DiscoveryFixture();
      fixture.events.first['title'] = 'Demo mit geschütztem Ort';
      await tester.pumpWidget(
        CommunityAccessApp(api: fixture, authOnly: true, showPublicHome: true),
      );
      await tester.pumpAndSettle();
      final title = tester.getRect(
        find.byKey(const ValueKey('hero-title-column')),
      );
      final information = tester.getRect(
        find.byKey(const ValueKey('hero-information-column')),
      );
      final controls = tester.getRect(
        find.byKey(const ValueKey('hero-carousel-controls')),
      );
      expect(controls.bottom, lessThan(title.top));
      expect(controls.right, closeTo(information.right, 1));
      expect(title.right, lessThan(information.left));
      expect(title.bottom, closeTo(information.bottom, 1));
      expect(title.left, greaterThanOrEqualTo(0));
      expect(information.right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Aushang light and dark fit $width at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = DiscoveryFixture();
        await tester.pumpWidget(
          CommunityAccessApp(
            api: fixture,
            authOnly: true,
            showPublicHome: true,
          ),
        );
        final context = tester.element(find.byType(PublicHomePage));
        tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
        );
        await tester.pumpAndSettle();
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          AppearanceScope.of(context)!.value = mode;
          await tester.pumpAndSettle();
          final palette = AushangPalette.of(context);
          expect(palette.dark, mode == ThemeMode.dark);
          expect(Theme.of(context).scaffoldBackgroundColor, palette.page);
          final controls = tester.getRect(
            find.byKey(const ValueKey('hero-carousel-controls')),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('hero-title-column')),
          );
          expect(controls.bottom, lessThan(title.top));
          expect(tester.takeException(), isNull);
          if (width < 768) {
            expect(find.text('Mein Zugang'), findsOneWidget);
            expect(find.text('Merkliste'), findsOneWidget);
          }
          await tester.ensureVisible(find.byTooltip('Nächste Veranstaltung'));
          await tester.tap(find.byTooltip('Nächste Veranstaltung'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(fixture.writes, isEmpty);
        }
      });
    }
  }

  testWidgets(
    'Forui action supports keyboard activation and disabled state in both themes',
    (tester) async {
      for (final dark in [false, true]) {
        var calls = 0;
        var enabled = true;
        late StateSetter rebuild;
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(dark: dark),
            home: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Scaffold(
                  body: AccessForuiTheme(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: AccessAction(
                        kind: AccessActionKind.primary,
                        onPressed: enabled ? () => calls++ : null,
                        child: const Text('Interesse bekunden'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final style =
            tester.widget<FButton>(find.byType(FButton)).style as FButtonStyle;
        expect(
          (style.decoration.resolve({}) as ShapeDecoration).color,
          AushangTokens.semanticSurfaceAccent,
        );
        expect(
          style.contentStyle.textStyle.resolve({}).color,
          AushangTokens.semanticTextOnAccent,
        );
        expect(style.focusedOutlineStyle.width, 2);
        expect(style.focusedOutlineStyle.spacing, 3);
        expect(
          tester.getSize(find.byType(FButton)).height,
          greaterThanOrEqualTo(48),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, 1);
        rebuild(() => enabled = false);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
