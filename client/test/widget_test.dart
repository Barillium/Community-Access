import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/main.dart';

class FakeApi implements AccessApi {
  @override
  Future<void> forgotPassword(String email) async {}
  @override
  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  ) async {}
  @override
  Future<void> verifyEmail(String email, String token) async {}
  @override
  Future<void> resendVerification() async {}
  @override
  Future<void> apply(
    String invitation,
    Object formId,
    Map<String, String> answers,
  ) async {}
  int withdrawals = 0;
  bool withdrawn = false;
  @override
  Future<void> withdrawApplication(Object id) async {
    withdrawals++;
    withdrawn = true;
  }

  @override
  Future<Map<String, dynamic>> invitation(String token) async => {
    'community': 'Synthetische Community',
  };
  @override
  Future<void> register(
    String invitation,
    String name,
    String email,
    String password,
    String confirmation,
  ) async {}
  String? requestStatus;
  bool admitted = true;
  bool fail = false;
  int requests = 0;
  @override
  Future<void> login(String email, String password) async {
    if (fail) throw const ApiFailure('Anmeldung fehlgeschlagen.');
  }

  @override
  Future<Map<String, dynamic>> snapshot() async => {
    'user': {'name': 'Gast A', 'email_verified': true},
    'applications': [
      {
        'id': 1,
        'community': 'Kollektiv Wolkenwinkel',
        'status': withdrawn ? 'withdrawn' : (admitted ? 'approved' : 'pending'),
      },
    ],
    'memberships': admitted
        ? [
            {'community': 'Kollektiv Wolkenwinkel', 'active': true},
          ]
        : [],
    'events': admitted
        ? [
            {
              'id': 1,
              'title': 'Synthetisches Event',
              'capacity': 1,
              'minimum_age': 18,
              'request_status': requestStatus,
            },
          ]
        : [],
  };
  @override
  Future<void> requestEvent(Object id) async {
    requests++;
    requestStatus = 'pending';
  }

  @override
  Future<Map<String, dynamic>> event(Object id) async {
    if (!admitted) {
      throw const ApiFailure(
        'Für diese Aktion fehlt die aktuelle Berechtigung.',
      );
    }
    final data = await snapshot();
    return {
      ...(data['events'] as List).first as Map<String, dynamic>,
      'community': 'Kollektiv Wolkenwinkel',
      'status': 'published',
      'starts_at': '2026-10-24T22:00:00+02:00',
      'lineup': 'Synthetischer Act A\nSynthetischer Act B',
      'genres': 'Demo-Genre',
      'description': 'Synthetische Eventbeschreibung.',
    };
  }

  @override
  Future<String> location(Object id) async => 'Erfundener Testort';
  @override
  Future<void> logout() async {}
  @override
  void close() {}
}

void main() {
  testWidgets(
    'age acknowledgement gates request and membership is not confirmation',
    (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(CommunityAccessApp(api: api));
      await tester.ensureVisible(find.text('Anmelden'));
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      final request = find.widgetWithText(
        FilledButton,
        'Eventteilnahme anfragen',
      );
      await tester.ensureVisible(request);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(request).onPressed, isNull);
      expect(find.text('Location abrufen'), findsNothing);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(request);
      await tester.tap(request);
      await tester.pumpAndSettle();
      expect(api.requests, 1);
      expect(find.text('Location abrufen'), findsNothing);
      expect(find.textContaining('Deine Anfrage ist offen'), findsOneWidget);
    },
  );
  testWidgets(
    'location is fetched only after confirmation and cleared on refreshed revocation',
    (tester) async {
      final api = FakeApi()..requestStatus = 'confirmed';
      await tester.pumpWidget(CommunityAccessApp(api: api));
      await tester.ensureVisible(find.text('Anmelden'));
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Location abrufen'),
      );
      await tester.tap(find.text('Location abrufen'));
      await tester.pumpAndSettle();
      expect(find.text('Erfundener Testort'), findsOneWidget);
      api.admitted = false;
      await tester.ensureVisible(find.text('Aktualisieren'));
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Erfundener Testort'), findsNothing);
      expect(find.text('Location abrufen'), findsNothing);
    },
  );
  testWidgets('narrow login with enlarged text has no layout exception', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: CommunityAccessApp(api: FakeApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('login failure is visible and leaves login available', (
    tester,
  ) async {
    await tester.pumpWidget(CommunityAccessApp(api: FakeApi()..fail = true));
    await tester.ensureVisible(find.text('Anmelden'));
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Anmeldung fehlgeschlagen.'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
  });
  testWidgets('guest controls meet tap target, label and contrast guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final api = FakeApi();
    await tester.pumpWidget(CommunityAccessApp(api: api));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    expect(
      tester
          .getSemantics(find.text('Teil einer Community werden.'))
          .getSemanticsData()
          .headingLevel,
      1,
    );
    final loginHeading = tester
        .getSemantics(find.text('Mit Demokonto anmelden'))
        .getSemanticsData();
    expect(loginHeading.headingLevel, 2);
    expect(loginHeading.label, 'Mit Demokonto anmelden');
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.ensureVisible(find.text('Anmelden'));
    await tester.pumpAndSettle();
    // Measure the complete selector, not its clipped sliver after scrolling to login.
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(DropdownButtonFormField<String>)).height,
      greaterThanOrEqualTo(48),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    api.requestStatus = 'confirmed';
    await tester.ensureVisible(find.text('Aktualisieren'));
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Location abrufen'),
    );
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('360px guest access remains usable at 200 percent text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      CommunityAccessApp(api: FakeApi()..requestStatus = 'confirmed'),
    );
    await tester.ensureVisible(find.text('Anmelden'));
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Location abrufen'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Location abrufen'));
    await tester.pumpAndSettle();
    expect(find.text('Erfundener Testort'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'event navigation filters only the authorized snapshot and resets on logout',
    (tester) async {
      final api = FakeApi();
      await tester.pumpWidget(CommunityAccessApp(api: api));
      await tester.ensureVisible(find.text('Anmelden'));
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bestätigt'));
      await tester.tap(find.text('Bestätigt'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Events für diese Auswahl.'), findsOneWidget);
      expect(find.text('Location abrufen'), findsNothing);
      expect(api.requests, 0);
      await tester.tap(find.text('Alle Events'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Event suchen'),
        'NICHT VORHANDEN',
      );
      await tester.pumpAndSettle();
      expect(find.text('Keine Events für diese Auswahl.'), findsOneWidget);
      await tester.tap(find.byTooltip('Suche leeren'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetisches Event'), findsOneWidget);
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Anmelden'));
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetisches Event'), findsOneWidget);
    },
  );

  testWidgets(
    'compact header navigates to events and community with accessible controls',
    (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        CommunityAccessApp(api: FakeApi()..requestStatus = 'confirmed'),
      );
      await tester.ensureVisible(find.text('Anmelden'));
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Community'));
      await tester.pumpAndSettle();
      final communityY = tester.getTopLeft(find.text('Bewerbungen')).dy;
      expect(communityY, greaterThan(100));
      expect(communityY, lessThan(300));
      await tester.tap(find.widgetWithText(TextButton, 'Events'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.widgetWithText(TextField, 'Event suchen')).dy,
        lessThan(400),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      expect(
        tester
            .getSemantics(find.widgetWithText(TextField, 'Event suchen'))
            .getSemanticsData()
            .label,
        'Event suchen',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'withdrawal needs explicit confirmation and cannot be repeated from the guest UI',
    (tester) async {
      final api = FakeApi()..admitted = false;
      await tester.pumpWidget(CommunityAccessApp(api: api));
      await tester.ensureVisible(find.text('Anmelden'));
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bewerbung zurückziehen'));
      await tester.tap(find.text('Bewerbung zurückziehen'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Mit einer gültigen Einladung kannst du dich erneut bewerben',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Zurück'));
      await tester.pumpAndSettle();
      expect(api.withdrawals, 0);
      await tester.tap(find.text('Bewerbung zurückziehen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rückzug bestätigen'));
      await tester.pumpAndSettle();
      expect(api.withdrawals, 1);
      expect(find.text('Bewerbung zurückziehen'), findsNothing);
      expect(
        find.textContaining('Du kannst dich erneut bewerben.'),
        findsOneWidget,
      );
      expect(find.text('Noch keine Mitgliedschaft.'), findsOneWidget);
    },
  );
}
