import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/invitation_page.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/contact_button.dart';

import 'widget_test.dart' show FakeApi;

class InvitationApi extends FakeApi {
  int applications = 0;
  Map<String, String>? submitted;
  String? terminalStatus;
  bool changed = false;
  String questionLabel = 'Synthetische Pflichtfrage';
  bool failApply = false;
  bool failStatus = false;
  @override
  Future<void> apply(
    String invitation,
    int formId,
    Map<String, String> answers,
  ) async {
    if (failApply) throw const ApiFailure('Das Formular wurde geändert.');
    applications++;
    submitted = answers;
  }

  @override
  Future<Map<String, dynamic>> snapshot() async {
    if (failStatus) throw const ApiFailure('Status nicht verfügbar.');
    return {
      'user': {'name': 'Synthetischer Gast', 'email_verified': true},
      'applications': [],
      'memberships': [],
      'events': [],
      'application_blocks': terminalStatus == null
          ? []
          : [
              {'community_id': 99, 'reason': terminalStatus},
            ],
    };
  }

  int previews = 0;
  int registrations = 0;
  bool unavailable = false;
  Completer<void>? delayedRegistration;
  @override
  Future<Map<String, dynamic>> invitation(String token) async {
    previews++;
    if (unavailable) {
      throw const ApiFailure(
        'Diese Einladung ist nicht verfügbar. Bitte frage die Gastgeber nach einem neuen Link.',
      );
    }
    return {
      'community_id': 99,
      'community': 'Synthetische Community',
      'host_contact': 'https://example.invalid/kontakt',
      'form': {
        'id': changed ? 2 : 1,
        'questions': [
          {
            'id': 'q1',
            'label': changed ? 'Neue synthetische Frage' : questionLabel,
            'required': true,
          },
          {'id': 'q2', 'label': 'Synthetische Zusatzfrage', 'required': false},
        ],
      },
    };
  }

  @override
  Future<void> register(
    String invitation,
    String name,
    String email,
    String password,
    String confirmation,
  ) async {
    registrations++;
    if (delayedRegistration != null) await delayedRegistration!.future;
  }
}

Future<void> enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

void main() {
  final token = 'a' * 64;
  test(
    'only exact local invitation links or raw synthetic tokens are accepted',
    () {
      expect(invitationToken('http://127.0.0.1:8300/#invite=$token'), token);
      expect(invitationToken(token), token);
      for (final link in [
        'https://example.invalid/#invite=$token',
        'http://127.0.0.1:8000/#invite=$token',
        'http://user@127.0.0.1:8300/#invite=$token',
        'http://127.0.0.1:8300/?invite=$token',
        'http://127.0.0.1:8300/#invite=${token}extra',
      ]) {
        expect(invitationToken(link), isNull);
      }
    },
  );
  testWidgets('invalid invitation does not expose registration', (
    tester,
  ) async {
    final api = InvitationApi()..unavailable = true;
    await tester.pumpWidget(
      CommunityAccessApp(api: api, initialInvitation: token),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Diese Einladung ist nicht verfügbar'),
      findsOneWidget,
    );
    expect(find.text('Konto anlegen'), findsNothing);
    expect(api.registrations, 0);
  });
  testWidgets(
    'valid invitation verifies account fields before registration and clears passwords',
    (tester) async {
      final api = InvitationApi();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, initialInvitation: token),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetische Community'), findsOneWidget);
      await enter(tester, 'Name', 'Synthetischer Gast C');
      await enter(tester, 'E-Mail', 'guest.c@example.invalid');
      await enter(tester, 'Passwort', 'Synthetisch-2026!');
      await enter(tester, 'Passwort wiederholen', 'different');
      await tester.ensureVisible(find.text('Konto anlegen'));
      await tester.tap(find.text('Konto anlegen'));
      await tester.pumpAndSettle();
      expect(api.registrations, 0);
      expect(
        find.text('Die Passwörter stimmen nicht überein.'),
        findsOneWidget,
      );
      await enter(tester, 'Passwort wiederholen', 'Synthetisch-2026!');
      await tester.ensureVisible(find.text('Konto anlegen'));
      await tester.tap(find.text('Konto anlegen'));
      await tester.pumpAndSettle();
      expect(api.registrations, 1);
      expect(find.text('Deine Bewerbung'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Passwort'), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'Antwort auf Frage 1'),
        findsOneWidget,
      );
      await Navigator.of(tester.element(find.text('Deine Bewerbung')))
          .maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Synthetischer Gast'), findsOneWidget);
      expect(find.text('Mit Demokonto anmelden'), findsNothing);
    },
  );
  testWidgets(
    'registration remains usable at 360px and 200 percent text size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CommunityAccessApp(
            api: InvitationApi(),
            initialInvitation: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextFormField, 'E-Mail'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );
  testWidgets(
    'host questions gate submission and optional answers can be left empty',
    (tester) async {
      final api = InvitationApi();
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationPage(
            api: api,
            authenticated: true,
            initialInvitation: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bewerbung einreichen'));
      await tester.tap(find.text('Bewerbung einreichen'));
      await tester.pumpAndSettle();
      expect(api.applications, 0);
      expect(find.text('Bitte ausfüllen.'), findsOneWidget);
      await enter(tester, 'Antwort auf Frage 1', 'Synthetische Antwort');
      await tester.ensureVisible(find.text('Bewerbung einreichen'));
      await tester.tap(find.text('Bewerbung einreichen'));
      await tester.pumpAndSettle();
      expect(api.applications, 1);
      expect(api.submitted, {'q1': 'Synthetische Antwort', 'q2': ''});
      expect(find.text('Bewerbung eingereicht.'), findsOneWidget);
      expect(find.text('Bewerbung einreichen'), findsNothing);
      expect(find.text('Location abrufen'), findsNothing);
    },
  );
  testWidgets('changed form can be refreshed without submitting old answers', (
    tester,
  ) async {
    final api = InvitationApi()..failApply = true;
    await tester.pumpWidget(
      MaterialApp(
        home: InvitationPage(
          api: api,
          authenticated: true,
          initialInvitation: token,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enter(tester, 'Antwort auf Frage 1', 'Synthetisch alt');
    await tester.ensureVisible(find.text('Bewerbung einreichen'));
    await tester.tap(find.text('Bewerbung einreichen'));
    await tester.pumpAndSettle();
    expect(find.text('Das Formular wurde geändert.'), findsOneWidget);
    api.changed = true;
    api.failApply = false;
    await tester.ensureVisible(find.text('Einladung aktualisieren'));
    await tester.tap(find.text('Einladung aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Neue synthetische Frage'), findsOneWidget);
    final input = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Antwort auf Frage 1'),
    );
    expect(input.controller!.text, isEmpty);
    expect(api.applications, 0);
  });
  for (final status in ['rejected', 'withdrawn']) {
    testWidgets('$status blocks another application and exposes host contact', (
      tester,
    ) async {
      final api = InvitationApi()..terminalStatus = status;
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationPage(
            api: api,
            authenticated: true,
            initialInvitation: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Eine erneute Bewerbung ist gesperrt'),
        findsOneWidget,
      );
      expect(find.text('Gastgeber kontaktieren'), findsOneWidget);
      expect(find.text('https://example.invalid/kontakt'), findsOneWidget);
      expect(find.text('Bewerbung einreichen'), findsNothing);
      expect(api.applications, 0);
    });
  }
  test('only safe synthetic host contact schemes are accepted', () {
    expect(isSyntheticContact('https://example.invalid/kontakt'), true);
    expect(isSyntheticContact('mailto:host@example.invalid'), true);
    for (final contact in [
      null,
      'javascript:alert(1)',
      'https://example.com',
      'https://user@example.invalid',
      'https://example.invalid:444',
      'mailto:host@example.com',
    ]) {
      expect(isSyntheticContact(contact), false);
    }
  });
  testWidgets(
    'application form remains accessible at 360px and 200 percent text size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: InvitationPage(
            api: InvitationApi(),
            authenticated: true,
            initialInvitation: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bewerbung einreichen'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );
  testWidgets(
    'registration in progress prevents a second submission and back navigation',
    (tester) async {
      final api = InvitationApi()..delayedRegistration = Completer<void>();
      await tester.pumpWidget(
        CommunityAccessApp(api: api, initialInvitation: token),
      );
      await tester.pumpAndSettle();
      await enter(tester, 'Name', 'Synthetisch');
      await enter(tester, 'E-Mail', 'guest.c@example.invalid');
      await enter(tester, 'Passwort', 'Synthetisch-2026!');
      await enter(tester, 'Passwort wiederholen', 'Synthetisch-2026!');
      await tester.ensureVisible(find.text('Konto anlegen'));
      await tester.tap(find.text('Konto anlegen'));
      await tester.pump();
      expect(api.registrations, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Konto anlegen'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.arrow_back),
            )
            .onPressed,
        isNull,
      );
      api.delayedRegistration!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Deine Bewerbung'), findsOneWidget);
      expect(api.registrations, 1);
    },
  );
  testWidgets('long host questions are shown in full on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final question =
        ('Synthetische lange Frage mit vollständiger Anzeige. ' * 4).substring(
          0,
          180,
        );
    final api = InvitationApi()..questionLabel = question;
    await tester.pumpWidget(
      MaterialApp(
        home: InvitationPage(
          api: api,
          authenticated: true,
          initialInvitation: token,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(question), findsOneWidget);
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Antwort auf Frage 1'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.text(question)).maxLines, isNull);
    expect(tester.widget<Text>(find.text(question)).overflow, isNull);
  });
  testWidgets(
    'application is unavailable until its current eligibility has been checked',
    (tester) async {
      final api = InvitationApi()..failStatus = true;
      await tester.pumpWidget(
        MaterialApp(
          home: InvitationPage(
            api: api,
            authenticated: true,
            initialInvitation: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Status nicht verfügbar.'), findsOneWidget);
      expect(find.text('Bewerbung einreichen'), findsNothing);
      expect(find.text('Bewerbungsstatus aktualisieren'), findsOneWidget);
      api.failStatus = false;
      await tester.tap(find.text('Bewerbungsstatus aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Bewerbung einreichen'), findsOneWidget);
      expect(api.applications, 0);
    },
  );
}
