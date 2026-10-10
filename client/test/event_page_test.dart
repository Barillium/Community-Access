import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/main.dart';

class DetailApi implements AccessApi {
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
  @override
  Future<void> withdrawApplication(Object id) async {}
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
  String status = 'published';
  bool allowed = true;
  int detailCalls = 0;
  int requests = 0;
  Completer<void>? requestCompletion;
  Map<String, dynamic> get detail => {
    'id': 1,
    'title': 'Synthetisches Event',
    'community': 'Kollektiv Wolkenwinkel',
    'status': status,
    'capacity': 2,
    'minimum_age': 18,
    'starts_at': '2026-10-24T22:00:00+02:00',
    'ends_at': '2026-10-25T03:00:00+01:00',
    'lineup': 'Synthetischer Act A\nSynthetischer Act B',
    'genres': 'Demo-Genre, Zweites Demo-Genre',
    'description': 'Synthetische Beschreibung.',
    'request_status': requestStatus,
  };
  @override
  Future<void> login(String email, String password) async {}
  @override
  Future<Map<String, dynamic>> snapshot() async => {
    'user': {'name': 'Gast A', 'email_verified': true},
    'applications': [],
    'memberships': [],
    'events': allowed ? [detail] : [],
  };
  @override
  Future<Map<String, dynamic>> event(Object id) async {
    detailCalls++;
    if (!allowed) {
      throw const ApiFailure(
        'Für diese Aktion fehlt die aktuelle Berechtigung.',
      );
    }
    return detail;
  }

  @override
  Future<void> requestEvent(Object id) async {
    requests++;
    if (requestCompletion != null) await requestCompletion!.future;
    requestStatus = 'pending';
  }

  @override
  Future<String> location(Object id) async {
    if (!allowed || status == 'cancelled') {
      throw const ApiFailure(
        'Für diese Aktion fehlt die aktuelle Berechtigung.',
      );
    }
    return 'Geschützter synthetischer Ort';
  }

  @override
  Future<void> logout() async {}
  @override
  void close() {}
}

Future<void> openDetails(WidgetTester tester, DetailApi api) async {
  await tester.pumpWidget(CommunityAccessApp(api: api));
  await tester.ensureVisible(find.text('Anmelden'));
  await tester.tap(find.text('Anmelden'));
  await tester.pumpAndSettle();
  final open = find.widgetWithText(OutlinedButton, 'Event ansehen');
  await tester.ensureVisible(open);
  await tester.tap(open);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'leaving during an in-flight request does not update the disposed detail page',
    (tester) async {
      final api = DetailApi()..requestCompletion = Completer<void>();
      await openDetails(tester, api);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final request = find.widgetWithText(
        FilledButton,
        'Eventteilnahme anfragen',
      );
      await tester.ensureVisible(request);
      await tester.tap(request);
      await tester.pump();
      await tester.tap(find.text('Alle Events'));
      await tester.pumpAndSettle();
      api.requestCompletion!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.requests, 1);
      expect(find.text('Events für dich.'), findsOneWidget);
    },
  );
  testWidgets(
    'detail reloads authorized content and age gates a real participation request',
    (tester) async {
      final api = DetailApi();
      await openDetails(tester, api);
      expect(api.detailCalls, 1);
      expect(find.text('Line-up'), findsOneWidget);
      expect(find.text('Synthetischer Act B'), findsOneWidget);
      expect(find.textContaining('24.10.2026 · 22:00'), findsOneWidget);
      expect(find.text('Geschützter synthetischer Ort'), findsNothing);
      final button = find.widgetWithText(
        FilledButton,
        'Eventteilnahme anfragen',
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.requests, 1);
      expect(api.detailCalls, 2);
      expect(find.text('Deine Anfrage ist offen.'), findsOneWidget);
      expect(find.text('Location abrufen'), findsNothing);
      await tester.tap(find.text('Alle Events'));
      await tester.pumpAndSettle();
      expect(find.text('Events für dich.'), findsOneWidget);
      expect(find.textContaining('Eventteilnahme: Offen'), findsOneWidget);
    },
  );

  testWidgets(
    'revocation while details are open clears event content and fetched location on refresh',
    (tester) async {
      final api = DetailApi()..requestStatus = 'confirmed';
      await openDetails(tester, api);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Location abrufen'),
      );
      await tester.tap(find.text('Location abrufen'));
      await tester.pumpAndSettle();
      expect(find.text('Geschützter synthetischer Ort'), findsOneWidget);
      api.allowed = false;
      await tester.tap(find.byTooltip('Event aktualisieren'));
      await tester.pumpAndSettle();
      expect(find.text('Geschützter synthetischer Ort'), findsNothing);
      expect(find.text('Synthetisches Event'), findsNothing);
      expect(find.text('Synthetischer Act A'), findsNothing);
      expect(find.text('Location abrufen'), findsNothing);
      expect(
        find.text('Für diese Aktion fehlt die aktuelle Berechtigung.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancelled detail exposes neither request nor location controls',
    (tester) async {
      final api = DetailApi()
        ..status = 'cancelled'
        ..requestStatus = 'cancelled';
      await openDetails(tester, api);
      expect(find.text('Event abgesagt'), findsOneWidget);
      expect(find.text('Location abrufen'), findsNothing);
      expect(find.text('Eventteilnahme anfragen'), findsNothing);
      expect(api.requests, 0);
    },
  );

  testWidgets(
    'detail controls pass basic accessibility checks and 200 percent text stays usable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      final api = DetailApi()..requestStatus = 'confirmed';
      await openDetails(tester, api);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getSemantics(find.text('Synthetisches Event'))
            .getSemanticsData()
            .headingLevel,
        1,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Location abrufen'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.text('Location abrufen'));
      await tester.pumpAndSettle();
      expect(find.text('Geschützter synthetischer Ort'), findsOneWidget);
      semantics.dispose();
    },
  );
}
