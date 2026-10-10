import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/event_directory_editor.dart';
import 'package:community_access_client/event_datetime_field.dart';
import 'package:community_access_client/event_drafts.dart';
import 'package:community_access_client/event_management_list.dart';
import 'package:community_access_client/design_system.dart';

import 'directory_widget_test.dart';
import 'field_finder.dart';

Future<void> showEditor(
  WidgetTester tester,
  DirectoryFixture api, {
  Map<String, dynamic>? event,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AccessDesign.theme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDirectoryEditor(
                  api: api,
                  communities: api.communities,
                  profileId: profileId,
                  profilePublic: true,
                  event: event,
                ),
              ),
            ),
            child: const Text('Editor öffnen'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Editor öffnen'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final field = fieldWithLabel(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  testWidgets(
    'local date and time inputs produce a real timestamp; invalid dates cannot normalize silently',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDateTimeField(controller: controller, label: 'Beginn'),
          ),
        ),
      );
      await enter(tester, 'Beginn: Datum', '31.10.2026');
      await enter(tester, 'Beginn: Uhrzeit', '20:15');
      expect(
        DateTime.parse(controller.text),
        DateTime(2026, 10, 31, 20, 15).toUtc(),
      );
      await enter(tester, 'Beginn: Datum', '31.02.2026');
      expect(eventDate(controller.text), isNull);
      expect(
        find.text('Bitte ein gültiges Datum und eine Uhrzeit eingeben.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Datum auswählen: Beginn'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Uhrzeit auswählen: Beginn'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
    },
  );
  testWidgets(
    'missing title and invalid capacity are marked locally without a write',
    (tester) async {
      final api = DirectoryFixture();
      await showEditor(tester, api);
      await enter(tester, 'Platzkapazität (leer = unbegrenzt)', '0');
      await tap(tester, 'Eventangaben speichern');
      expect(api.bodies, isEmpty);
      expect(find.text('Bitte einen Eventtitel eingeben.'), findsOneWidget);
      expect(
        find.text(
          'Bitte eine positive ganze Platzzahl eingeben oder das Feld leer lassen.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'leaving can retain and restore a draft, and discard it explicitly',
    (tester) async {
      final api = DirectoryFixture();
      await showEditor(tester, api);
      await enter(tester, 'Eventtitel', 'Demo ungespeichert');
      await enter(tester, 'Platzkapazität (leer = unbegrenzt)', 'kein Wert');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ungespeicherte Eventangaben'), findsOneWidget);
      await tap(tester, 'Weiter bearbeiten');
      expect(find.text('Demo ungespeichert'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Entwurf behalten');
      await tap(tester, 'Editor öffnen');
      expect(find.text('Demo ungespeichert'), findsOneWidget);
      expect(find.text('kein Wert'), findsOneWidget);
      expect(
        find.text('Dein ungespeicherter Entwurf wurde wiederhergestellt.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, 'Entwurf verwerfen');
      await tap(tester, 'Editor öffnen');
      expect(find.text('Demo ungespeichert'), findsNothing);
      expect(api.bodies, isEmpty);
    },
  );
  testWidgets(
    'publication requires an end after the beginning and retains the draft on validation failure',
    (tester) async {
      final api = DirectoryFixture();
      await showEditor(
        tester,
        api,
        event: const {
          'id': 'event',
          'version': 1,
          'title': 'Demo Veröffentlichung',
          'status': 'published',
          'community_id': 'community',
          'access_mode': 'private',
          'starts_at': '2030-11-02T20:00:00Z',
        },
      );
      await tap(tester, 'Eventangaben speichern');
      expect(api.bodies, isEmpty);
      expect(
        find.text('Für die Veröffentlichung ist eine Endzeit erforderlich.'),
        findsOneWidget,
      );
      await enter(tester, 'Ende: Datum', '01.11.2030');
      await enter(tester, 'Ende: Uhrzeit', '18:00');
      await tap(tester, 'Eventangaben speichern');
      expect(
        find.text('Das Ende muss nach dem Beginn liegen.'),
        findsOneWidget,
      );
      expect(api.bodies, isEmpty);
    },
  );
  testWidgets(
    'server failure preserves entered values and a restored edit never upgrades its stale version silently',
    (tester) async {
      final api = DirectoryFixture()..directoryFails = true;
      EventDrafts.forApi(api).write('$profileId/event', {
        'id': 'event',
        'version': 1,
        'title': 'Demo ältere Bearbeitung',
        'status': 'draft',
        'community_id': 'community',
        'access_mode': 'private',
      });
      await showEditor(
        tester,
        api,
        event: const {
          'id': 'event',
          'version': 2,
          'title': 'Demo aktueller Stand',
          'status': 'draft',
          'community_id': 'community',
          'access_mode': 'private',
        },
      );
      expect(find.textContaining('älteren Stand'), findsOneWidget);
      await tap(tester, 'Eventangaben speichern');
      expect(api.bodies.single['version'], 1);
      expect(find.text('Demo ältere Bearbeitung'), findsOneWidget);
      expect(EventDrafts.forApi(api).read('$profileId/event')!['version'], 1);
    },
  );
  testWidgets(
    'explicit save sends only API fields and removes the local draft',
    (tester) async {
      final api = DirectoryFixture();
      await showEditor(tester, api);
      await enter(tester, 'Eventtitel', 'Demo dauerhafter Entwurf');
      await tap(tester, 'Eventangaben speichern');
      expect(api.bodies.single['status'], 'draft');
      expect(api.bodies.single.containsKey('_capacity_input'), false);
      expect(EventDrafts.forApi(api).read('$profileId/new'), isNull);
      expect(find.text('Editor öffnen'), findsOneWidget);
    },
  );
  testWidgets(
    'session change erases an open draft and prevents any write from the old editor',
    (tester) async {
      final api = DirectoryFixture();
      await showEditor(tester, api);
      await enter(
        tester,
        'Geschützte genaue Location',
        'Geschützter synthetischer Ort',
      );
      EventDrafts.forApi(api).clear();
      await tester.pumpAndSettle();
      expect(find.text('Geschützter synthetischer Ort'), findsNothing);
      await tester.ensureVisible(find.text('Eventangaben speichern'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Eventangaben speichern'),
      );
      expect(button.onPressed, isNull);
      expect(api.bodies, isEmpty);
    },
  );
  test('login, logout and expiry clear session drafts rather than retaining another account content', () async {
    var expire = false;
    final api = BetterAuthAccessApi(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(expire ? {'code': 'UNAUTHENTICATED'} : {}),
          expire ? 401 : 200,
          headers: {'set-auth-token': 'signed-synthetic'},
        ),
      ),
    );
    final drafts = EventDrafts.forApi(api);
    drafts.write('demo', {'title': 'Synthetischer Entwurf'});
    await api.login('demo@example.invalid', 'Synthetic-2026!');
    expect(drafts.read('demo'), isNull);
    drafts.write('demo', {'title': 'Synthetischer Entwurf'});
    await api.logout();
    expect(drafts.read('demo'), isNull);
    drafts.write('demo', {'title': 'Synthetischer Entwurf'});
    expire = true;
    await expectLater(api.directory('manage'), throwsException);
    expect(drafts.read('demo'), isNull);
    api.close();
  });
  test('event copies omit identity and all guest rights; follow-up uses local calendar days', () {
    final start = DateTime(2026, 10, 24, 22), end = DateTime(2026, 10, 25, 5);
    final source = {
      'id': 'source',
      'version': 4,
      'title': 'Demo wiederkehrend',
      'status': 'published',
      'starts_at': start.toUtc().toIso8601String(),
      'event_content': {
        'description': 'Demo',
        'ends_at': end.toUtc().toIso8601String(),
      },
      'request_deadline_at': DateTime(
        2026,
        10,
        23,
        18,
      ).toUtc().toIso8601String(),
      'grants': ['synthetic'],
      'event_requests': ['synthetic'],
      'confirmed_count': 5,
    };
    final copy = eventCopy(source);
    expect(copy['status'], 'draft');
    expect(copy['starts_at'], isNull);
    for (final key in [
      'id',
      'version',
      'grants',
      'event_requests',
      'confirmed_count',
    ]) {
      expect(copy.containsKey(key), false);
    }
    final next = eventCopy(source, afterDays: 7);
    expect(eventDate(next['starts_at'] as String), DateTime(2026, 10, 31, 22));
    expect(
      eventDate(next['event_content']['ends_at'] as String),
      DateTime(2026, 11, 1, 5),
    );
    expect(
      eventDate(next['request_deadline_at'] as String),
      DateTime(2026, 10, 30, 18),
    );
    next['event_content']['description'] = 'Änderung';
    expect(
      source['event_content'],
      isA<Map>().having((m) => m['description'], 'original content', 'Demo'),
    );
  });
  testWidgets(
    'overview filters events and displays current available capacity without treating requests as reservations',
    (tester) async {
      final clicked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventManagementList(
                busy: false,
                events: const [
                  {
                    'id': 'one',
                    'title': 'Demo Abend',
                    'status': 'published',
                    'pending_count': 4,
                    'confirmed_count': 2,
                    'capacity': 8,
                    'available_places': 6,
                  },
                  {'id': 'two', 'title': 'Demo Entwurf', 'status': 'draft'},
                ],
                onEdit: (e) => clicked.add('edit'),
                onDuplicate: (e) => clicked.add('copy'),
                onNext: (e) => clicked.add('next'),
                onPreview: (e) => clicked.add('preview'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('4 offene Anfragen · 2 Zusagen'), findsOneWidget);
      expect(find.text('6 freie Plätze von 8'), findsOneWidget);
      await enter(tester, 'Eigene Events suchen', 'Abend');
      expect(find.text('Demo Entwurf'), findsNothing);
      await tap(tester, 'Event duplizieren');
      expect(clicked, ['copy']);
    },
  );
  for (final width in [320.0, 375.0, 1280.0]) {
    testWidgets(
      'new date controls and full editor fit $width with doubled text',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = DirectoryFixture();
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: TextScaler.linear(2),
              ),
              child: EventDirectoryEditor(
                api: api,
                communities: api.communities,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Eventangaben speichern'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
