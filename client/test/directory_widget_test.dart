import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/organizer_management_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/access_api.dart';

import 'auth_account_widget_test.dart' show AuthAccountApi;

const profileId = '00000000-0000-4000-8000-000000000001';

class DirectoryFixture extends AuthAccountApi implements DirectoryApi {
  bool closed = false;
  @override
  void close() {
    closed = true;
  }

  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  bool directoryFails = false,
      signedIn = false,
      approved = false,
      pending = false,
      private = false;
  final communities = [
    {'id': 'community', 'name': 'Demo Musik'},
  ];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (closed) throw const ApiFailure('Client was closed');
    calls.add('$path:${query ?? {}}');
    if (body != null) bodies.add(body);
    if (directoryFails) {
      throw const ApiFailure('Testfehler: Bitte erneut laden.');
    }
    if (path == 'organizers') {
      return {
        'items': query?['q'] == 'leer' || (private && (!signedIn || !approved))
            ? []
            : [
                {
                  'id': profileId,
                  'name': 'Demo Kollektiv',
                  'description': 'Demo Beschreibung',
                  'is_public': !private,
                  'communities': communities,
                },
              ],
        'communities': communities,
        'signed_in': signedIn,
        'has_more': false,
      };
    }
    if (path == 'venues') {
      return {
        'items': [
          {'name': 'Demo Kulturhalle', 'event_count': 2},
        ],
        'has_more': false,
      };
    }
    if (path == 'venue') {
      return {
        'events': [
          {
            'id': 'e',
            'title': 'Demo vergangener Abend',
            'community': 'Demo Musik',
            'starts_at': null,
            'status': 'cancelled',
          },
        ],
      };
    }
    if (path == 'organizers/$profileId') {
      if (private && (!signedIn || !approved)) {
        throw const ApiFailure('Dieser Eintrag ist nicht verfügbar.');
      }
      return {
        'id': profileId,
        'name': 'Demo Kollektiv',
        'description': 'Demo Beschreibung',
        'communities': communities,
      };
    }
    if (path.endsWith('/access')) {
      if (private && !signedIn) {
        throw const ApiFailure('Dieser Eintrag ist nicht verfügbar.');
      }
      return {
        'id': profileId,
        'name': private && !approved ? 'Profilzugang' : 'Demo Kollektiv',
        'signed_in': signedIn,
        'allow_application': false,
        'allow_form': true,
        'allow_link': true,
        'version': 1,
        'form': [
          {'key': 'interest', 'label': 'Deine Frage', 'required': true},
        ],
        'request': pending ? {'id': 'r', 'status': 'pending'} : null,
      };
    }
    if (path.endsWith('/apply')) {
      pending = true;
      return {};
    }
    if (path.endsWith('/redeem')) {
      approved = true;
      return {};
    }
    if (path == 'manage') {
      return {
        'profile': {
          'id': profileId,
          'name': 'Demo Kollektiv',
          'description': 'Demo Beschreibung',
          'awareness_concept': true,
          'awareness_team': false,
          'is_public': false,
          'allow_application': true,
          'allow_form': true,
          'allow_link': true,
          'version': 1,
          'community_ids': ['community'],
          'form': [
            {
              'key': 'interest',
              'label': 'Was interessiert dich an unserem Programm?',
              'required': true,
            },
          ],
        },
        'communities': communities,
        'requests': [],
        'links': [],
        'events': [],
      };
    }
    return {};
  }
}

void main() {
  testWidgets(
    'navigation connects both directories, organizer name search and Community filter to API',
    (tester) async {
      final api = DirectoryFixture();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Menü'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          matching: find.text('Veranstalter'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo Kollektiv'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'leer');
      await tester.ensureVisible(find.text('Suchen'));
      await tester.tap(find.text('Suchen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Keine Veranstalterprofile für diese Auswahl.'),
        findsOneWidget,
      );
      expect(api.calls.last, contains('q: leer'));
      await tester.tap(find.text('Zurücksetzen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo Musik').last);
      await tester.pumpAndSettle();
      expect(api.calls.last, contains('community: community'));
      await tester.ensureVisible(find.byTooltip('Menü'));
      await tester.tap(find.byTooltip('Menü'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          matching: find.text('Veranstaltungsorte'),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
          matching: find.text('Veranstaltungsorte'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo Kulturhalle'), findsOneWidget);
      await tester.ensureVisible(find.text('Veranstaltungen ansehen'));
      await tester.tap(find.text('Veranstaltungen ansehen'));
      await tester.pumpAndSettle();
      expect(find.text('Demo vergangener Abend'), findsOneWidget);
      expect(find.text('Abgesagt'), findsOneWidget);
      expect(find.text('Beginn nicht öffentlich freigegeben'), findsOneWidget);
    },
  );
  testWidgets(
    'form request uses server fields and waits for manual approval; personal link grants only profile',
    (tester) async {
      final api = DirectoryFixture()
        ..private = true
        ..signedIn = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: OrganizerDetailPage(
            api: api,
            id: profileId,
            token: 'test-token',
            openAccount: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Demo Beschreibung'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Synthetische Antwort');
      await tester.ensureVisible(find.text('Profilzugriff anfragen'));
      await tester.tap(find.text('Profilzugriff anfragen'));
      await tester.pumpAndSettle();
      expect(api.bodies.last, {
        'method': 'form',
        'version': 1,
        'answers': {'interest': 'Synthetische Antwort'},
      });
      expect(find.text('Wartet auf Freigabe'), findsOneWidget);
      await tester.ensureVisible(
        find.text('Persönlichen Zugangslink einlösen'),
      );
      await tester.tap(find.text('Persönlichen Zugangslink einlösen'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Beschreibung'), findsOneWidget);
      expect(
        find.text(
          'Profilzugriff bestätigt keine Communitymitgliedschaft oder Eventteilnahme.',
        ),
        findsNothing,
      );
    },
  );
  testWidgets('load error is separate from empty state and recoverable', (
    tester,
  ) async {
    final api = DirectoryFixture()..directoryFails = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AccessDesign.theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DirectoryBrowser(
              api: api,
              venues: false,
              openAccount: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Testfehler: Bitte erneut laden.'), findsOneWidget);
    expect(
      find.text('Keine Veranstalterprofile für diese Auswahl.'),
      findsNothing,
    );
    api.directoryFails = false;
    await tester.ensureVisible(find.text('Erneut laden'));
    await tester.tap(find.text('Erneut laden'));
    await tester.pumpAndSettle();
    expect(find.text('Demo Kollektiv'), findsOneWidget);
  });
  testWidgets(
    'host editor saves actual public flags, selected Communities and custom questions',
    (tester) async {
      final api = DirectoryFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: OrganizerManagementPage(api: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Profilname'),
        'Demo neuer Name',
      );
      await tester.ensureVisible(find.text('Profil speichern'));
      await tester.tap(find.text('Profil speichern'));
      await tester.pumpAndSettle();
      expect(api.bodies.last['name'], 'Demo neuer Name');
      expect(api.bodies.last['community_ids'], ['community']);
      expect(api.bodies.last['form'], [
        {
          'key': 'interest',
          'label': 'Was interessiert dich an unserem Programm?',
          'required': true,
        },
      ]);
      expect(api.bodies.last['is_public'], false);
    },
  );
  testWidgets(
    'shared profile opens before account navigation and survives the login return',
    (tester) async {
      final api = DirectoryFixture()..private = true;
      await tester.pumpWidget(
        CommunityAccessApp(
          api: api,
          authOnly: true,
          showPublicHome: true,
          initialOrganizer: profileId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrganizerDetailPage), findsOneWidget);
      await tester.ensureVisible(find.text('Anmelden oder Konto anlegen'));
      await tester.tap(find.text('Anmelden oder Konto anlegen'));
      await tester.pumpAndSettle();
      expect(find.text('Mit deinem Testkonto anmelden'), findsOneWidget);
      await tester.tap(find.text('Zurück'));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizerDetailPage), findsOneWidget);
      expect(find.text('Demo Kollektiv'), findsNothing);
      expect(find.text('Anmelden oder Konto anlegen'), findsOneWidget);
      expect(api.closed, false);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(api.closed, true);
    },
  );
  testWidgets(
    'anonymous directory never announces personal profiles; granted profiles only appear signed in',
    (tester) async {
      final api = DirectoryFixture();
      Future<void> render() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: DirectoryBrowser(
                  api: api,
                  venues: false,
                  openAccount: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await render();
      expect(find.text('Demo Kollektiv'), findsOneWidget);
      expect(find.textContaining('persönlich'), findsNothing);
      expect(find.text('Profilzugang öffnen'), findsNothing);
      api.private = true;
      api.approved = true;
      await render();
      expect(find.text('Demo Kollektiv'), findsNothing);
      api.signedIn = true;
      await render();
      expect(find.text('Demo Kollektiv'), findsOneWidget);
      expect(find.text('Persönlich für dich freigegeben'), findsNothing);
      api.signedIn = false;
      await render();
      expect(find.text('Demo Kollektiv'), findsNothing);
    },
  );
  for (final size in [const Size(375, 900), const Size(320, 900)]) {
    testWidgets('directories and management fit $size and doubled text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DirectoryFixture();
      for (final page in [
        DirectoryBrowser(api: api, venues: false, openAccount: () async {}),
        DirectoryBrowser(api: api, venues: true, openAccount: () async {}),
        OrganizerManagementPage(api: api),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page is OrganizerManagementPage
                ? page
                : Scaffold(body: SingleChildScrollView(child: page)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  }
}
