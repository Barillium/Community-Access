import 'package:community_access_client/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:community_access_client/account_registration_page.dart';
import 'package:community_access_client/better_auth_api.dart';

import 'package:community_access_client/auth_mode.dart';
import 'package:community_access_client/account_recovery_page.dart';

class FixtureAccountApi implements AccountApi {
  int calls = 0;
  @override
  Future<void> createAccount(String name, String email, String password) async {
    calls++;
  }
}

void main() {
  test('account validation and links follow the explicit runtime mode', () {
    expect(allowedAccountEmail('fixture@example.test'), privateMailMode);
    expect(allowedAccountEmail('fixture@example.invalid'), !privateMailMode);
    expect(allowedAccountEmail('bad\naddress@example.test'), false);
    expect(allowedAccountEmail('no-address'), false);
    final email = privateMailMode
        ? 'fixture@example.test'
        : 'fixture@example.invalid';
    final link =
        'http://127.0.0.1:8300/#verify=${'a' * 64}&email=${Uri.encodeComponent(email)}';
    expect(accountLink(link)?.kind, 'verify');
    expect(
      accountLink(link.replaceFirst('127.0.0.1', 'foreign.example.test')),
      isNull,
    );
    expect(accountLink('$link&extra=yes'), isNull);
  });
  testWidgets(
    'registration and mailbox controls match the selected mail mode',
    (tester) async {
      final api = FixtureAccountApi();
      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/register',
          routes: {
            '/': (_) => const Scaffold(body: LocalMailboxButton()),
            '/register': (_) => AccountRegistrationPage(api: api),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(privateMailMode ? 'Dein Konto' : 'Dein Testkonto'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Synthetic fixture',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        privateMailMode ? 'fixture@example.test' : 'fixture@example.invalid',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Synthetic-2026!',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Synthetic-2026!',
      );
      await tester.ensureVisible(find.byType(AccessAction));
      await tester.tap(find.byType(AccessAction));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LocalMailboxButton())),
      );
      expect(
        find.text('Lokales Testpostfach öffnen'),
        privateMailMode ? findsNothing : findsOneWidget,
      );
    },
  );
}
