import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/directory_pages.dart';
import 'package:community_access_client/event_content_fields.dart';
import 'package:community_access_client/invitation_page.dart';
import 'package:community_access_client/site_information_page.dart';

import 'directory_widget_test.dart' show DirectoryFixture, profileId;
import 'invitation_page_test.dart' show InvitationApi;

class PilotProfileApi extends DirectoryFixture {
  PilotProfileApi() {
    private = true;
    signedIn = true;
  }

  bool failSubmission = false, failRefresh = false, loseAcknowledgement = false;
  int version = 1, submissions = 0;
  Completer<void>? delayedSubmission;

  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (path.endsWith('/apply')) {
      submissions++;
      if (delayedSubmission != null) await delayedSubmission!.future;
      if (failSubmission) throw const ApiFailure('Verbindung unterbrochen.');
      final response = await super.directory(path, query: query, body: body);
      if (loseAcknowledgement) {
        throw const ApiFailure('Verbindung unterbrochen.');
      }
      return response;
    }
    if (path.endsWith('/access')) {
      if (failRefresh && submissions > 0) {
        throw const ApiFailure('Status konnte nicht geladen werden.');
      }
      final response = await super.directory(path, query: query, body: body);
      return {
        ...response,
        'version': version,
        'form': [
          {'key': 'interest', 'label': 'Synthetische Frage', 'required': true},
          {'key': 'extra', 'label': 'Synthetischer Zusatz', 'required': false},
        ],
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

Future<void> profile(WidgetTester tester, PilotProfileApi api) async {
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
}

Finder answer() => find.byKey(const ValueKey('profile-answer-interest'));

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Profilzugriff anfragen'));
  await tester.tap(find.text('Profilzugriff anfragen'));
  await tester.pumpAndSettle();
}

Future<void> refresh(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Aktualisieren'));
  await tester.tap(find.text('Aktualisieren'));
  await tester.pumpAndSettle();
}

class PendingAfterWithdrawalApi extends InvitationApi {
  @override
  Future<Map<String, dynamic>> snapshot() async => {
    ...await super.snapshot(),
    'applications': [
      {'community_id': 99, 'status': 'pending'},
      {'community_id': 99, 'status': 'withdrawn'},
    ],
  };
}

void main() {
  testWidgets(
    'a possible account change clears a draft kept after a connection failure',
    (tester) async {
      final api = PilotProfileApi()..failSubmission = true;
      int accountVisits = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: OrganizerDetailPage(
            api: api,
            id: profileId,
            openAccount: () async {
              accountVisits++;
              api.failRefresh = false;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        answer(),
        'Synthetischer Entwurf für das erste Konto',
      );
      await submit(tester);
      api.failRefresh = true;
      await refresh(tester);
      await tester.ensureVisible(find.text('Anmelden oder Konto anlegen'));
      await tester.tap(find.text('Anmelden oder Konto anlegen'));
      await tester.pumpAndSettle();
      expect(accountVisits, 1);
      expect(tester.widget<TextFormField>(answer()).controller!.text, isEmpty);
      expect(api.submissions, 1);
    },
  );
  testWidgets(
    'shared contact route gives one recipient without requiring an account',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: const Scaffold(body: SiteInformationLinks()),
        ),
      );
      await tester.tap(find.text('Hilfe & Kontakt'));
      await tester.pumpAndSettle();
      expect(find.text(siteContactInformation), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const Key('site-contact-readable')))
            .getSemanticsData()
            .label,
        siteContactInformation,
      );
      expect(siteContactEmail, 'info@communityaccess.de');
      expect(find.text('E-Mail schreiben'), findsOneWidget);
      // The native test stub opens nothing and offers a copyable fallback.
      await tester.tap(find.text('E-Mail schreiben'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kopiere die Adresse in dein E-Mail-Programm.'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );
  testWidgets('profile request validates required fields before sending', (
    tester,
  ) async {
    final api = PilotProfileApi();
    await profile(tester, api);
    expect(
      find.textContaining('zuständigen Gastgeber dieses Profils'),
      findsOneWidget,
    );
    expect(
      find.textContaining('keine Communitymitgliedschaft'),
      findsOneWidget,
    );
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Datenschutz'), findsOneWidget);
    await submit(tester);
    expect(api.submissions, 0);
    expect(find.text('Bitte beantworte diese Pflichtfrage.'), findsOneWidget);
    await tester.enterText(answer(), 'Synthetische Antwort');
    await submit(tester);
    expect(api.submissions, 1);
    expect(api.bodies.last['answers'], {
      'interest': 'Synthetische Antwort',
      'extra': '',
    });
    expect(find.text('Wartet auf Freigabe'), findsOneWidget);
    expect(
      find.textContaining('Beim Rückzug werden deine Antworten entfernt'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed submission keeps answers and requires status refresh before retry',
    (tester) async {
      final api = PilotProfileApi()..failSubmission = true;
      await profile(tester, api);
      await tester.enterText(answer(), 'Synthetischer Entwurf');
      await submit(tester);
      expect(
        tester.widget<TextFormField>(answer()).controller!.text,
        'Synthetischer Entwurf',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Profilzugriff anfragen'),
            )
            .onPressed,
        isNull,
      );
      expect(api.submissions, 1);
      api.failSubmission = false;
      await refresh(tester);
      expect(
        tester.widget<TextFormField>(answer()).controller!.text,
        'Synthetischer Entwurf',
      );
      await submit(tester);
      expect(api.submissions, 2);
      expect(find.text('Wartet auf Freigabe'), findsOneWidget);
    },
  );

  testWidgets(
    'lost response after server commit does not cause duplicate submission',
    (tester) async {
      final api = PilotProfileApi()..loseAcknowledgement = true;
      await profile(tester, api);
      await tester.enterText(answer(), 'Synthetische Antwort');
      await submit(tester);
      expect(api.pending, isTrue);
      await refresh(tester);
      expect(find.text('Wartet auf Freigabe'), findsOneWidget);
      expect(find.text('Profilzugriff anfragen'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(api.submissions, 1);
    },
  );

  testWidgets('confirmed action with failed reload reports incomplete status', (
    tester,
  ) async {
    final api = PilotProfileApi()..failRefresh = true;
    await profile(tester, api);
    await tester.enterText(answer(), 'Synthetische Antwort');
    await submit(tester);
    expect(
      find.textContaining(
        'aber der aktuelle Status konnte nicht geladen werden',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Anfrage eingereicht. Der Gastgeber entscheidet manuell.'),
      findsNothing,
    );
    expect(find.text('Wartet auf Freigabe'), findsNothing);
    api.failRefresh = false;
    await refresh(tester);
    expect(find.text('Wartet auf Freigabe'), findsOneWidget);
    expect(api.submissions, 1);
  });

  testWidgets(
    'changed form version discards old draft instead of answering different questions',
    (tester) async {
      final api = PilotProfileApi()..failSubmission = true;
      await profile(tester, api);
      await tester.enterText(answer(), 'Synthetischer alter Entwurf');
      await submit(tester);
      api.version = 2;
      await refresh(tester);
      expect(tester.widget<TextFormField>(answer()).controller!.text, isEmpty);
      expect(
        find.textContaining('Das Formular wurde geändert.'),
        findsOneWidget,
      );
      expect(api.submissions, 1);
    },
  );

  testWidgets('two immediate activations send one profile request', (
    tester,
  ) async {
    final api = PilotProfileApi()..delayedSubmission = Completer<void>();
    await profile(tester, api);
    await tester.enterText(answer(), 'Synthetische Antwort');
    final action = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Profilzugriff anfragen'),
        )
        .onPressed!;
    action();
    action();
    await tester.pump();
    expect(api.submissions, 1);
    api.delayedSubmission!.complete();
    await tester.pumpAndSettle();
    expect(api.submissions, 1);
  });

  testWidgets(
    'public profile is readable without offering anonymous personal submission',
    (tester) async {
      final api = PilotProfileApi()
        ..private = false
        ..signedIn = false;
      await profile(tester, api);
      expect(find.text('Demo Beschreibung'), findsOneWidget);
      expect(find.text('Profilzugriff anfragen'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(api.submissions, 0);
    },
  );

  testWidgets(
    'profile fields remain keyboard reachable at narrow width and large text',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = PilotProfileApi();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: OrganizerDetailPage(
            api: api,
            id: profileId,
            openAccount: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(answer());
      await tester.tap(answer());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-answer-extra')),
          matching: find.byType(EditableText),
        ),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'flyer rights and privacy guidance appear alongside image selection',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventContentFields(
                initial: const {},
                enabled: true,
                onChanged: (_) {},
                chooseFlyer: () async => null,
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Verwende nur Bilder, die du hier zeigen darfst'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Keine geschützten Adressen im Flyer'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Flyer auswählen'));
      await tester.tap(find.text('Flyer auswählen'));
      await tester.pumpAndSettle();
      expect(find.text('Flyer auswählen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'voluntary community withdrawal permits a new application with valid invitation',
    (tester) async {
      final api = InvitationApi()..terminalStatus = 'withdrawn';
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationPage(
            api: api,
            authenticated: true,
            initialInvitation: 'a' * 64,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Du kannst dich mit dieser gültigen Einladung erneut bewerben',
        ),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Antwort auf Frage 1'),
        'Synthetische neue Bewerbung',
      );
      await tester.ensureVisible(find.text('Bewerbung einreichen'));
      await tester.tap(find.text('Bewerbung einreichen'));
      await tester.pumpAndSettle();
      expect(api.applications, 1);
      expect(find.text('Bewerbung eingereicht.'), findsOneWidget);
    },
  );

  testWidgets(
    'historic withdrawal never overrides a current pending application',
    (tester) async {
      final api = PendingAfterWithdrawalApi()..terminalStatus = 'withdrawn';
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationPage(
            api: api,
            authenticated: true,
            initialInvitation: 'a' * 64,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bewerbung eingereicht.'), findsOneWidget);
      expect(find.text('Bewerbung einreichen'), findsNothing);
      expect(api.applications, 0);
    },
  );
}
