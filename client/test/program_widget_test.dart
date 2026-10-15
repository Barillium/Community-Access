import 'field_finder.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/program_management_page.dart';
import 'package:community_access_client/program_views.dart';

import 'directory_widget_test.dart';

const seriesId = '00000000-0000-4000-8000-000000000002';
const eventId = '00000000-0000-4000-8000-000000000003';

class ProgramFixture extends DirectoryFixture {
  bool allowed = false;
  bool paged = false;
  int grantVersion = 1;
  bool hasGrant = false;
  List<Map<String, dynamic>> get series => [
    {
      'id': seriesId,
      'title': 'Demo Nebelreihe',
      'description': 'Demo Reihenbeschreibung',
      'community_id': 'community',
      'is_public': false,
      'version': 1,
    },
  ];
  List<Map<String, dynamic>> get events => [
    {
      'id': eventId,
      'title': 'Demo Nebelabend',
      'status': 'published',
      'starts_at': null,
      'location': 'Demo Nebelort',
      'public_location': 'Demo Nebelort',
      'location_public': true,
      'starts_public': false,
      'is_public': false,
      'community_id': 'community',
      'series_id': seriesId,
      'version': 1,
    },
  ];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path == 'manage') {
      final data = await super.directory(path, query: query, body: body);
      return {
        ...data,
        'series': series,
        'events': events,
        'grants': [
          if (hasGrant)
            {
              'id': 'grant',
              'kind': 'series',
              'scope_id': seriesId,
              'title': 'Demo Nebelreihe',
              'guest': 'Demo Gast',
              'email': 'guest.a@example.invalid',
              'active': allowed,
              'version': grantVersion,
            },
        ],
      };
    }
    if (path == 'organizers/$profileId/program') {
      calls.add('$path:${query ?? {}}');
      if (allowed && paged) {
        final page = int.parse(query?['page'] ?? '1');
        return {
          'series': [],
          'events': [
            {
              ...events.first,
              'title': page == 1 ? 'Demo Termin eins' : 'Demo Termin zwei',
            },
          ],
          'page': page,
          'has_more': page == 1,
        };
      }
      return allowed
          ? {'series': series, 'events': events}
          : {'series': [], 'events': []};
    }
    if (path == 'series/$seriesId') {
      if (!allowed) {
        throw const ApiFailure('Dieser Eintrag ist nicht verfügbar.');
      }
      return {...series.first, 'events': events};
    }
    if (path == 'events/$eventId') {
      if (!allowed) {
        throw const ApiFailure('Dieser Eintrag ist nicht verfügbar.');
      }
      return {
        ...events.first,
        'series': 'Demo Nebelreihe',
        'community': 'Demo Musik',
      };
    }
    if (path == 'manage/grant' || path == 'manage/revoke') {
      calls.add('$path:${query ?? {}}');
      bodies.add(body!);
      allowed = path == 'manage/grant';
      hasGrant = true;
      grantVersion++;
      return {};
    }
    return super.directory(path, query: query, body: body);
  }
}

void main() {
  testWidgets(
    'profile program requests another server-filtered page without a hidden event count',
    (tester) async {
      final api = ProgramFixture()
        ..allowed = true
        ..paged = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: OrganizerDetailPage(
            api: api,
            id: profileId,
            openAccount: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo Termin eins'), findsOneWidget);
      await tester.ensureVisible(find.text('Weitere Veranstaltungen'));
      await tester.tap(find.text('Weitere Veranstaltungen'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Termin eins'), findsNothing);
      expect(find.text('Demo Termin zwei'), findsOneWidget);
      expect(api.calls.last, contains('page: 2'));
    },
  );
  testWidgets(
    'public profile contains no placeholder for hidden program; granted events appear and vanish on refresh after revocation',
    (tester) async {
      final api = ProgramFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: OrganizerDetailPage(
            api: api,
            id: profileId,
            openAccount: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo Kollektiv'), findsOneWidget);
      expect(find.text('Demo Nebelreihe'), findsNothing);
      expect(find.text('Veranstaltungen'), findsNothing);
      expect(find.textContaining('Freigabe'), findsNothing);
      api.allowed = true;
      await tester.ensureVisible(find.text('Aktualisieren'));
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Nebelreihe'), findsOneWidget);
      expect(find.text('Demo Nebelabend'), findsOneWidget);
      await tester.ensureVisible(find.text('Event ansehen'));
      await tester.tap(find.text('Event ansehen'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Nebelabend'), findsOneWidget);
      api.allowed = false;
      await tester.ensureVisible(find.text('Aktualisieren'));
      await tester.ensureVisible(find.text('Aktualisieren'));
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Nebelabend'), findsNothing);
      expect(find.text('Demo Nebelort'), findsNothing);
      expect(find.text('Dieser Eintrag ist nicht verfügbar.'), findsOneWidget);
    },
  );
  testWidgets(
    'host grants and revokes the selected series; regrant uses the current server version',
    (tester) async {
      final api = ProgramFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: ProgramManagementPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        fieldWithLabel(
          DropdownButtonFormField<String>,
          'Reihe oder einzelnes Event',
        ),
      );
      await tester.tap(
        fieldWithLabel(
          DropdownButtonFormField<String>,
          'Reihe oder einzelnes Event',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reihe: Demo Nebelreihe').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'E-Mail des Gastkontos'),
        'guest.a@example.invalid',
      );
      await tester.ensureVisible(find.text('Sichtbarkeit freigeben'));
      await tester.tap(find.text('Sichtbarkeit freigeben'));
      await tester.pumpAndSettle();
      expect(api.bodies.last, {
        'kind': 'series',
        'id': seriesId,
        'email': 'guest.a@example.invalid',
      });
      await tester.ensureVisible(find.text('Sichtbarkeit entziehen'));
      await tester.tap(find.text('Sichtbarkeit entziehen'));
      await tester.pumpAndSettle();
      expect(api.bodies.last, {'kind': 'series', 'id': 'grant', 'version': 2});
      await tester.ensureVisible(find.text('Erneut freigeben'));
      await tester.tap(find.text('Erneut freigeben'));
      await tester.pumpAndSettle();
      expect(api.bodies.last, {
        'kind': 'series',
        'id': seriesId,
        'email': 'guest.a@example.invalid',
        'version': 3,
      });
    },
  );
  testWidgets(
    'host creates a protected series and assigns an event to it without making it public',
    (tester) async {
      final api = ProgramFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: ProgramManagementPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reihe anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name der Reihe'),
        'Demo neue Reihe',
      );
      await tester.ensureVisible(find.text('Reihe speichern'));
      await tester.tap(find.text('Reihe speichern'));
      await tester.pumpAndSettle();
      expect(api.bodies.last['is_public'], false);
      expect(api.bodies.last['title'], 'Demo neue Reihe');
      await tester.ensureVisible(find.text('Event anlegen'));
      await tester.tap(find.text('Event anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Eventtitel'),
        'Demo neues Event',
      );
      await tester.ensureVisible(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Veranstaltungsreihe',
        ),
      );
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Veranstaltungsreihe',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo Nebelreihe').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Eventangaben speichern'));
      await tester.tap(find.text('Eventangaben speichern'));
      await tester.pumpAndSettle();
      expect(api.bodies.last['series_id'], seriesId);
      expect(api.bodies.last['is_public'], false);
    },
  );
  for (final size in [const Size(375, 900), const Size(320, 900)]) {
    testWidgets('program and host editors fit $size with doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ProgramFixture()
        ..allowed = true
        ..hasGrant = true;
      for (final page in [
        ProgramManagementPage(api: api),
        SeriesEditor(api: api, communities: api.communities),
        ProgramDetailPage(api: api, kind: 'series', id: seriesId),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
