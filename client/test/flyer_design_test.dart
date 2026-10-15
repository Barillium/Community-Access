import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/flyer_design.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/event_carousel.dart';
import 'package:community_access_client/event_editorial_view.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/program_views.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

void main() {
  setUpAll(() async {
    final font = FontLoader('Archivo')
      ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Archivo-Italic-Variable.ttf'));
    await font.load();
  });
  testWidgets('event surfaces omit visibility labels in both languages', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final mode in ['public', 'private', 'semi_public']) {
        for (final english in [false, true]) {
          final event = <String, dynamic>{
            'id': 'synthetic',
            'title': 'Demo Termin',
            'organizer': 'Demo Kollektiv',
            'status': 'published',
            'starts_at': '2026-11-21T22:00:00Z',
            'access_mode': mode,
            'is_public': mode == 'public',
            'location': '',
            'event_content': <String, dynamic>{},
          };
          await tester.pumpWidget(
            MaterialApp(
              theme: AccessDesign.theme(),
              home: LanguageScope(
                language: AppLanguage()..value = english,
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        EventCarousel(events: [event], onOpen: (_) {}),
                        for (final calendar in [false, true])
                          ProgramList(
                            api: DiscoveryFixture(),
                            calendarLayout: calendar,
                            showHeading: false,
                            program: {
                              'events': [event],
                            },
                          ),
                        EventEditorialView(event: event),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Demo Termin'), findsNWidgets(4));
          expect(
            find.text(
              english
                  ? 'Attendance is confirmed separately.'
                  : 'Teilnahme wird separat bestätigt.',
            ),
            findsOneWidget,
          );
          expect(
            find.text(english ? 'Not released yet' : 'Noch nicht freigegeben'),
            findsOneWidget,
          );
          for (final label in [
            'Öffentlich',
            'Semi-öffentlich',
            'Mit Zugang',
            'Privat',
            'Public',
            'Semi-public',
            'With access',
            'Private',
          ]) {
            expect(find.text(label), findsNothing, reason: '$mode / $english');
            expect(
              find.bySemanticsLabel(RegExp('\\b${RegExp.escape(label)}\\b')),
              findsNothing,
              reason: 'No visibility classification in semantics',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    } finally {
      semantics.dispose();
    }
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Flyer home and menu fit $width at $scale text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
        );
        final api = DiscoveryFixture();
        await tester.pumpWidget(
          CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
        );
        await tester.pumpAndSettle();
        final error = tester.takeException();
        if (error is FlutterError) {
          debugPrint(error.toStringDeep());
        }
        expect(error, isNull);
        if (width == 1440 && scale == 1) {
          expect(
            tester.getSize(find.byType(AccessHeader)).height,
            lessThanOrEqualTo(68),
          );
        }
        expect(find.text('Programm.'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        expect(find.bySemanticsLabel('Das Programm.'), findsOneWidget);
        semantics.dispose();
        expect(find.byTooltip('Plakatwechsel starten'), findsOneWidget);
        final scene = find.byType(FlyerScene).first;
        final rect = tester.getRect(scene);
        expect(rect.width, closeTo(width, 1));
        final controls = find.byKey(const ValueKey('hero-carousel-controls'));
        final controlsRect = tester.getRect(controls);
        expect(controlsRect.top, closeTo(rect.top + 16, 1));
        expect(controlsRect.right, lessThanOrEqualTo(rect.right - 16));
        expect(controlsRect.left, greaterThanOrEqualTo(rect.left));
        expect(controlsRect.bottom, lessThan(rect.bottom));
        if (width >= 900 && scale == 1) {
          expect(rect.height, greaterThanOrEqualTo(720));
        } else {
          final titleRect = tester.getRect(
            find.byKey(const ValueKey('hero-title-column')),
          );
          expect(titleRect.top, greaterThanOrEqualTo(rect.top + 280));
        }
        await tester.pump(const Duration(seconds: 20));
        expect(
          find.descendant(
            of: find.byType(EventCarousel),
            matching: find.text('Demo Ambientabend'),
          ),
          findsOneWidget,
        );
        final menu = find.byTooltip('Menü');
        if (menu.evaluate().isNotEmpty) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
          expect(find.text('Mein Zugang'), findsWidgets);
          final marked = find.ancestor(
            of: find.text('Mein Zugang').last,
            matching: find.byType(FlyerMark),
          );
          expect(tester.widget<FlyerMark>(marked).kind, FlyerMarkKind.circle);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(PopupMenuItem), findsNothing);
        }
        expect(tester.takeException(), isNull);
        expect(api.writes, isEmpty);
      });
    }
  }
  testWidgets('language dropdown is rightmost and retains chosen event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CommunityAccessApp(
        api: DiscoveryFixture(),
        authOnly: true,
        showPublicHome: true,
      ),
    );
    await tester.pumpAndSettle();
    final access = tester.getRect(
      find.widgetWithText(TextButton, 'Mein Zugang'),
    );
    final search = tester.getRect(find.byTooltip('Suche öffnen'));
    final language = tester.getRect(find.byType(FlyerLanguageButton));
    expect(access.right, lessThanOrEqualTo(search.left));
    expect(search.right, lessThanOrEqualTo(language.left));
    await tester.tap(find.byTooltip('Nächste Veranstaltung'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sprache auswählen'));
    await tester.pumpAndSettle();
    expect(find.text('Deutsch'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Program.'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Choose language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Programm.'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('language dropdown supports keyboard dismissal and selection', (
    tester,
  ) async {
    final language = AppLanguage();
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: Scaffold(
          body: LanguageScope(
            language: language,
            child: const Align(
              alignment: Alignment.topRight,
              child: FlyerLanguageButton(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsNothing);
    expect(language.value, isFalse);
    // Focus returns to the trigger, so Enter opens it again without Tab.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(Focus.of(tester.element(find.text('English'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(language.value, isTrue);
    expect(find.text('EN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing event media and hidden locations stay absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: EventEditorialView(
              event: {
                'title': 'Testevent',
                'location': '',
                'event_content': {},
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Noch nicht freigegeben'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('header focus is orange and keyboard actions remain usable', (
    tester,
  ) async {
    final states = WidgetStatesController();
    addTearDown(states.dispose);
    ThemeData? headerTheme;
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: Scaffold(
          body: AccessHeader(
            child: Builder(
              builder: (context) {
                headerTheme = Theme.of(context);
                return TextButton(
                  statesController: states,
                  onPressed: () => pressed++,
                  child: const Text('Programm'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(states.value, contains(WidgetState.focused));
    final theme = headerTheme!;
    for (final style in [
      theme.textButtonTheme.style!,
      theme.iconButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.filledButtonTheme.style!,
      theme.elevatedButtonTheme.style!,
    ]) {
      expect(style.side!.resolve({}), BorderSide.none);
      final focused = style.side!.resolve(states.value)!;
      expect(focused.color, FlyerStyle.marker);
      expect(focused.width, greaterThanOrEqualTo(2));
      expect(
        1.05 / (focused.color.computeLuminance() + .05),
        greaterThanOrEqualTo(3),
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('white header stays white in dark theme and has 48px controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(dark: true),
        home: Scaffold(
          body: LanguageScope(
            language: AppLanguage(),
            child: AccessHeader(
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const AccessIcon(Icons.menu),
                  ),
                  const FlyerLanguageButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = find.byType(AccessHeader);
    final box = find
        .descendant(of: header, matching: find.byType(Container))
        .first;
    expect(
      (tester.widget<Container>(box).decoration as BoxDecoration).color,
      Colors.white,
    );
    expect(
      tester.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(FlyerLanguageButton)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
