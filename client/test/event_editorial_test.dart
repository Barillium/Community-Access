import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/event_editorial_view.dart';
import 'package:community_access_client/event_content_fields.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/flyer_design.dart';

import 'program_widget_test.dart';
import 'directory_widget_test.dart' show profileId;

const demoFlyer =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS9sAAAAASUVORK5CYII=';
Map<String, dynamic> demoEvent() => {
  'title': 'Demo Nachtlinie',
  'status': 'published',
  'starts_at': '2026-11-20T22:00:00Z',
  'location': 'Demo Stadtteil',
  'organizer': 'Demo Kollektiv',
  'event_content': {
    'description': 'Demo Beschreibung mit zwei Absätzen.\n\nZweiter Absatz.',
    'line_up': ['Demo Wellenraum', 'Demo Lichtspur'],
    'genres': ['Techno', 'Ambient'],
    'venue_name': 'Demo Halle',
    'ends_at': '2026-11-21T04:00:00Z',
    'minimum_age': 18,
    'admission': 'Demo Einlass nach separater Zusage.',
    'flyer_data': demoFlyer,
    'flyer_alt': 'Demo grünes Motiv',
  },
  'access_details': {'step_free': 'yes'},
};
Future<void> render(
  WidgetTester tester,
  Widget widget, {
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? ThemeData.dark() : AccessDesign.theme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: widget,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final ratio in [.8, 16 / 9]) {
      testWidgets(
        'full poster keeps its ratio without text overlap at $width / $ratio',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final event = demoEvent();
          event['event_content']['flyer_aspect_ratio'] = ratio;
          await render(tester, EventEditorialView(event: event));
          final originalFlyer = find.byType(EventFlyer).first;
          final flyer = tester.getRect(originalFlyer);
          final title = tester.getRect(find.byType(FlyerTitle));
          expect(flyer.width / flyer.height, closeTo(ratio, .001));
          expect(flyer.left, greaterThanOrEqualTo(0));
          expect(flyer.right, lessThanOrEqualTo(width));
          expect(flyer.overlaps(title), isFalse);
          expect(
            tester.widget<Image>(find.byType(Image).first).fit,
            BoxFit.contain,
          );
          if (width < 900) {
            final transition = tester.getRect(
              find.byKey(const ValueKey('poster-transition')),
            );
            expect(transition.top, closeTo(flyer.bottom, .001));
            expect(transition.bottom, lessThanOrEqualTo(title.top));
            expect(flyer.overlaps(transition), isFalse);
            final semantics = tester.ensureSemantics();
            expect(find.bySemanticsLabel('Demo grünes Motiv'), findsOneWidget);
            semantics.dispose();
            expect(flyer.bottom, lessThanOrEqualTo(title.top));
          } else {
            expect(title.right, lessThanOrEqualTo(flyer.left));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'host age choice stays editable and youth protection is explained without a mandatory default',
    (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? content;
      await render(
        tester,
        EventContentFields(
          initial: const {},
          enabled: true,
          onChanged: (value) => content = value,
        ),
      );
      final age = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is AccessField &&
              widget.decoration.labelText == 'Mindestalter (optional)',
        ),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(age).controller!.text, isEmpty);
      await tester.ensureVisible(age);
      await tester.enterText(age, '16');
      expect(content!['minimum_age'], 16);
      expect(find.text(eventAgeGuidance), findsOneWidget);
      expect(find.textContaining('16- und 17-Jährige'), findsNothing);
      await tester.ensureVisible(find.text('Jugendschutz beachten'));
      await tester.tap(find.text('Jugendschutz beachten'));
      await tester.pumpAndSettle();
      expect(find.textContaining('längstens bis 24 Uhr'), findsOneWidget);
      expect(find.textContaining('Nachtbars, Nachtclubs'), findsOneWidget);
      expect(
        find.textContaining('ersetzt keine nötige Alters-'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Jugendschutzgesetz ansehen'));
      await tester.tap(find.text('Jugendschutzgesetz ansehen'));
      await tester.pumpAndSettle();
      expect(find.text('Gesetzestext: $youthProtectionLawUrl'), findsOneWidget);
      expect(content!['minimum_age'], 16);
      await tester.ensureVisible(age);
      await tester.enterText(age, '');
      expect(content!['minimum_age'], isNull);
      expect(find.text(eventAgeGuidance), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'event renders genuine supplied information and accessible media without zoom action',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await render(tester, EventEditorialView(event: demoEvent()));
      expect(find.text('Demo Nachtlinie'), findsOneWidget);
      expect(find.text('Demo Halle'), findsOneWidget);
      expect(find.text('Demo Wellenraum'), findsOneWidget);
      expect(find.text('Mindestalter: 18 Jahre'), findsOneWidget);
      expect(find.text('Demo Einlass nach separater Zusage.'), findsOneWidget);
      expect(find.text('Techno'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'Demo grünes Motiv');
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.text('Flyer ansehen'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'legacy empty event has no invented line-up, age, description or media',
    (tester) async {
      await render(
        tester,
        const EventEditorialView(
          event: {'title': 'Demo Altbestand', 'status': 'cancelled'},
        ),
      );
      expect(find.text('Dieses Event ist abgesagt.'), findsOneWidget);
      expect(find.text('Line-up'), findsNothing);
      expect(find.text('Einlass'), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Noch nicht freigegeben'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'content fields keep supplied values, explicit media replacement and removal',
    (tester) async {
      Map<String, dynamic>? out;
      await render(
        tester,
        EventContentFields(
          initial: demoEvent()['event_content'],
          enabled: true,
          onChanged: (value) => out = value,
          chooseFlyer: () async => demoFlyer,
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Beschreibung'),
        'Demo Bearbeitung',
      );
      expect(out!['line_up'], ['Demo Wellenraum', 'Demo Lichtspur']);
      expect(out!['description'], 'Demo Bearbeitung');
      final remove = find.text('Flyer entfernen');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(out!['flyer_data'], '');
      await tester.ensureVisible(find.text('Flyer auswählen'));
      await tester.tap(find.text('Flyer auswählen'));
      await tester.pumpAndSettle();
      expect(out!['flyer_data'], demoFlyer);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'host editor submits content and preview applies the selected time and location flags',
    (tester) async {
      final api = ProgramFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: EventDirectoryEditor(
            api: api,
            communities: api.communities,
            series: api.series,
            profileId: profileId,
            profilePublic: true,
            event: {
              ...api.events.first,
              'starts_at': '2026-11-20T22:00:00Z',
              'starts_public': false,
              'location_public': false,
              'event_content': demoEvent()['event_content'],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Beschreibung'),
        'Demo gespeichert',
      );
      final preview = find.text('Seite vorab ansehen');
      await tester.ensureVisible(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(find.text('Demo Halle'), findsNothing);
      expect(find.textContaining('bis Sa.'), findsNothing);
      expect(find.text('Demo gespeichert'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final save = find.text('Eventangaben speichern');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        api.bodies.last['event_content']['description'],
        'Demo gespeichert',
      );
      expect(api.bodies.last['event_content']['minimum_age'], 18);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(320, 900),
    const Size(375, 900),
    const Size(1280, 900),
  ]) {
    testWidgets('editorial event fits $size and doubled text in both themes', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : AccessDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: EventEditorialView(event: demoEvent()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
