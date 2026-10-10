import 'dart:async';

import 'package:community_access_client/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/main.dart';

import 'widget_test.dart' show FakeApi;

class AuthAccountApi extends FakeApi implements AccountApi {
  int registrations = 0;
  bool expired = false;
  @override
  Future<void> createAccount(String name, String email, String password) async {
    registrations++;
  }

  @override
  Future<Map<String, dynamic>> snapshot() async {
    if (expired) {
      throw const ApiFailure('Sitzung abgelaufen.', unauthenticated: true);
    }
    return {
      'user': {
        'name': 'Synthetic',
        'email': 'auth@example.invalid',
        'email_verified': false,
      },
      'product_available': false,
      'applications': [],
      'memberships': [],
      'events': [],
    };
  }
}

void main() {
  testWidgets(
    'rate-limited sign-in releases input focus and allows manual retry without access',
    (tester) async {
      final api = RateLimitedAccountApi();
      await tester.pumpWidget(CommunityAccessApp(api: api, authOnly: true));
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'auth@example.invalid');
      await tester.enterText(fields.at(1), 'Synthetic-2026!');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.tap(find.widgetWithText(FilledButton, 'Anmelden'));
      await tester.pump();
      expect(api.logins, 1);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: fields.at(1),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      api.request.completeError(
        const ApiFailure(
          'Zu viele Anfragen. Bitte warte 17 Sekunden und versuche es erneut.',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Zu viele Anfragen. Bitte warte 17 Sekunden und versuche es erneut.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(fields.at(0)).controller!.text,
        'auth@example.invalid',
      );
      expect(tester.widget<TextField>(fields.at(1)).enabled, isTrue);
      expect(find.text('Dein Konto.'), findsNothing);
      expect(api.logins, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'account form preserves identity and cannot invent membership or events',
    (tester) async {
      final api = AuthAccountApi();
      await tester.pumpWidget(CommunityAccessApp(api: api, authOnly: true));
      expect(find.text('Mit Demokonto anmelden'), findsNothing);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Testkonto anlegen'),
      );
      await tester.tap(find.text('Testkonto anlegen'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Synthetic');
      await tester.enterText(fields.at(1), 'auth@example.invalid');
      await tester.enterText(fields.at(2), 'Synthetic-2026!');
      await tester.enterText(fields.at(3), 'Synthetic-2026!');
      await tester.ensureVisible(
        find.widgetWithText(AccessAction, 'Testkonto anlegen'),
      );
      await tester.tap(find.widgetWithText(AccessAction, 'Testkonto anlegen'));
      await tester.pumpAndSettle();
      expect(api.registrations, 1);
      expect(
        find.textContaining(
          'Bestätige deine E-Mail-Adresse und melde dich danach an.',
        ),
        findsOneWidget,
      );
      expect(find.text('Bestätigungslink erneut anfordern'), findsNothing);
      expect(find.text('Eventteilnahme anfragen'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Zur Anmeldung'));
      await tester.pumpAndSettle();
      expect(find.text('Mit deinem Testkonto anmelden'), findsOneWidget);
    },
  );

  testWidgets('synthetic registration rejects real email and mismatch', (
    tester,
  ) async {
    final api = AuthAccountApi();
    await tester.pumpWidget(CommunityAccessApp(api: api, authOnly: true));
    await tester.ensureVisible(find.text('Testkonto anlegen'));
    await tester.tap(find.text('Testkonto anlegen'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Synthetic');
    await tester.enterText(fields.at(1), 'real@example.com');
    await tester.enterText(fields.at(2), 'Synthetic-2026!');
    await tester.enterText(fields.at(3), 'Other-2026!');
    await tester.ensureVisible(
      find.widgetWithText(AccessAction, 'Testkonto anlegen'),
    );
    await tester.tap(find.widgetWithText(AccessAction, 'Testkonto anlegen'));
    await tester.pumpAndSettle();
    expect(api.registrations, 0);
    expect(
      find.text('Verwende eine Adresse mit @example.invalid.'),
      findsOneWidget,
    );
    expect(find.text('Die Passwörter stimmen nicht überein.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class RateLimitedAccountApi extends AuthAccountApi {
  int logins = 0;
  final request = Completer<void>();
  @override
  Future<void> login(String email, String password) {
    logins++;
    return request.future;
  }
}
