import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/account_recovery_page.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/invitation_page.dart';

import 'widget_test.dart' show FakeApi;
import 'invitation_page_test.dart' show InvitationApi;

class RecoveryApi extends FakeApi {
  int forgot = 0, resets = 0, verifications = 0, resends = 0;
  String? submittedEmail;
  String? submittedPassword;
  Completer<void>? pending;
  bool verified = false;
  bool failForgot = false;
  @override
  Future<void> forgotPassword(String email) async {
    forgot++;
    submittedEmail = email;
    if (failForgot) {
      throw const ApiFailure('Der lokale Dienst ist gerade nicht erreichbar.');
    }
  }

  @override
  Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirmation,
  ) async {
    resets++;
    submittedPassword = password;
    if (pending != null) await pending!.future;
  }

  @override
  Future<void> verifyEmail(String email, String token) async {
    verifications++;
    verified = true;
  }

  @override
  Future<void> resendVerification() async {
    resends++;
  }

  @override
  Future<Map<String, dynamic>> snapshot() async => {
    ...await super.snapshot(),
    'user': {
      'name': 'Synthetischer Gast',
      'email': 'guest.c@example.invalid',
      'email_verified': verified,
    },
  };
}

class UnverifiedInvitationApi extends InvitationApi {
  bool verified = false;
  int resends = 0;
  @override
  Future<void> resendVerification() async {
    resends++;
  }

  @override
  Future<Map<String, dynamic>> snapshot() async => {
    ...await super.snapshot(),
    'user': {
      'name': 'Synthetischer Gast',
      'email': 'guest.c@example.invalid',
      'email_verified': verified,
    },
  };
}

Future<void> input(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> action(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  final token = List.filled(64, 'a').join();
  test('account links accept only exact local fragment structure', () {
    final prefix = 'http://127.0.0.1:8300/';
    expect(accountLink('$prefix#forgot')?.kind, 'forgot');
    expect(
      accountLink('$prefix#verify=$token&email=guest.c%40example.invalid')
          ?.email,
      'guest.c@example.invalid',
    );
    expect(
      accountLink('$prefix#reset=$token&email=guest.c%40example.invalid')
          ?.token,
      token,
    );
    for (final value in [
      'https://127.0.0.1:8300/#verify=$token&email=guest.c%40example.invalid',
      'http://example.invalid/#reset=$token&email=guest.c%40example.invalid',
      '$prefix?token=$token#reset=$token&email=guest.c%40example.invalid',
      '$prefix#verify=$token&email=guest.c%40example.invalid&reset=$token',
      '$prefix#reset=$token&email=real%40example.com',
      '$prefix#verify=bad&email=guest.c%40example.invalid',
    ]) {
      expect(accountLink(value), isNull);
    }
  });
  test('recovery tokens remain in POST bodies and successful reset discards old bearer', () async {
    final seen = <http.Request>[];
    final api = HttpAccessApi(
      client: MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/api/login') {
          return http.Response(jsonEncode({'token': 'synthetic-bearer'}), 200);
        }
        return http.Response('{}', 200);
      }),
    );
    await api.login('guest.a@example.invalid', 'synthetic-password');
    await api.forgotPassword(' GUEST.A@EXAMPLE.INVALID ');
    await api.verifyEmail('guest.a@example.invalid', token);
    await api.resendVerification();
    await api.resetPassword(
      'guest.a@example.invalid',
      token,
      'synthetic-new-password',
      'synthetic-new-password',
    );
    await api.snapshot();
    for (final request in seen) {
      expect(request.url.toString(), isNot(contains(token)));
      expect(request.url.query, isEmpty);
    }
    expect(jsonDecode(seen[1].body)['email'], 'guest.a@example.invalid');
    expect(jsonDecode(seen[2].body)['token'], token);
    expect(seen[4].headers['authorization'], 'Bearer synthetic-bearer');
    expect(seen[5].headers.containsKey('authorization'), isFalse);
    api.close();
  });
  testWidgets(
    'forgot password validates synthetic email and uses neutral success copy',
    (tester) async {
      final api = RecoveryApi();
      await tester.pumpWidget(
        CommunityAccessApp(
          api: api,
          initialAccountLink: const AccountLinkData('forgot'),
        ),
      );
      await tester.pumpAndSettle();
      await input(tester, 'E-Mail', 'real@example.com');
      await action(tester, 'Wiederherstellungslink anfordern');
      expect(api.forgot, 0);
      await input(tester, 'E-Mail', 'unknown@example.invalid');
      await action(tester, 'Wiederherstellungslink anfordern');
      expect(api.forgot, 1);
      expect(
        find.textContaining('Wenn ein Konto mit dieser Adresse existiert'),
        findsOneWidget,
      );
      expect(find.text('Zur Anmeldung'), findsOneWidget);
    },
  );
  testWidgets(
    'reset validates confirmation and byte bound and prevents duplicate submission',
    (tester) async {
      final api = RecoveryApi()..pending = Completer<void>();
      await tester.pumpWidget(
        CommunityAccessApp(
          api: api,
          initialAccountLink: AccountLinkData(
            'reset',
            email: 'guest.c@example.invalid',
            token: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await input(tester, 'Neues Passwort', 'short');
      await input(tester, 'Passwort bestätigen', 'short');
      await action(tester, 'Passwort speichern');
      expect(api.resets, 0);
      final tooLong = List.filled(37, 'ä').join();
      await input(tester, 'Neues Passwort', tooLong);
      await input(tester, 'Passwort bestätigen', tooLong);
      await action(tester, 'Passwort speichern');
      expect(api.resets, 0);
      await input(tester, 'Neues Passwort', 'synthetic-new-password');
      await input(tester, 'Passwort bestätigen', 'different');
      await action(tester, 'Passwort speichern');
      expect(api.resets, 0);
      await input(tester, 'Passwort bestätigen', 'synthetic-new-password');
      await tester.ensureVisible(find.text('Passwort speichern'));
      await tester.tap(find.text('Passwort speichern'));
      await tester.pump();
      expect(api.resets, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Passwort speichern'),
            )
            .onPressed,
        isNull,
      );
      api.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Passwort geändert.'), findsOneWidget);
      await action(tester, 'Zur Anmeldung');
      expect(find.text('Mit deinem Testkonto anmelden'), findsOneWidget);
    },
  );
  testWidgets(
    'verification link requires explicit confirmation and does not sign in',
    (tester) async {
      final api = RecoveryApi();
      await tester.pumpWidget(
        CommunityAccessApp(
          api: api,
          initialAccountLink: AccountLinkData(
            'verify',
            email: 'guest.c@example.invalid',
            token: token,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.verifications, 0);
      await action(tester, 'E-Mail-Adresse bestätigen');
      expect(api.verifications, 1);
      await action(tester, 'Zur Anmeldung');
      expect(find.text('Anmelden'), findsOneWidget);
      expect(find.text('Abmelden'), findsNothing);
    },
  );
  testWidgets(
    'unverified guest gets resend and refresh instead of private event controls',
    (tester) async {
      final api = RecoveryApi();
      await tester.pumpWidget(CommunityAccessApp(api: api));
      await action(tester, 'Anmelden');
      expect(find.text('E-Mail bestätigen'), findsOneWidget);
      expect(find.text('Eventteilnahme anfragen'), findsNothing);
      await action(tester, 'Bestätigungslink erneut anfordern');
      expect(api.resends, 1);
      api.verified = true;
      await action(tester, 'Bestätigung prüfen');
      expect(find.text('E-Mail bestätigen'), findsNothing);
      expect(find.text('Eventteilnahme anfragen'), findsOneWidget);
    },
  );
  testWidgets('invitation hides application until verification refresh', (
    tester,
  ) async {
    final api = UnverifiedInvitationApi();
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
    expect(find.text('Bewerbung einreichen'), findsNothing);
    await action(tester, 'Bestätigungslink erneut anfordern');
    expect(api.resends, 1);
    api.verified = true;
    await action(tester, 'Bestätigung prüfen');
    expect(find.text('Bewerbung einreichen'), findsOneWidget);
  });
  testWidgets(
    'recovery handles service failure and remains accessible at 360px and 200 percent text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final api = RecoveryApi()..failForgot = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: AccountRecoveryPage(
              api: api,
              link: const AccountLinkData('forgot'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await input(tester, 'E-Mail', 'unknown@example.invalid');
      await action(tester, 'Wiederherstellungslink anfordern');
      expect(
        find.text('Der lokale Dienst ist gerade nicht erreichbar.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );
}
