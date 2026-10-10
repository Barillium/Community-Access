import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/account_recovery_page.dart';

import 'auth_account_widget_test.dart' show AuthAccountApi;

void main() {
  testWidgets('public entry reaches account and returns without signing in', (
    tester,
  ) async {
    final api = AuthAccountApi();
    await tester.pumpWidget(
      CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Events & Communities.'), findsOneWidget);
    expect(find.text('Anmelden'), findsOneWidget);
    expect(find.text('Synthetisches Event'), findsNothing);
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Mit deinem Testkonto anmelden'), findsOneWidget);
    await tester.tap(find.text('Zur Hauptseite'));
    await tester.pumpAndSettle();
    expect(find.text('Events & Communities.'), findsOneWidget);
    expect(api.registrations, 0);
  });

  testWidgets('public search and navigation never reveal private fixtures', (
    tester,
  ) async {
    await tester.pumpWidget(
      CommunityAccessApp(
        api: AuthAccountApi(),
        authOnly: true,
        showPublicHome: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Synthetisches Event');
    await tester.ensureVisible(find.text('Suchen'));
    await tester.tap(find.text('Suchen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Öffentliche Events sind derzeit nicht verfügbar.'),
      findsOneWidget,
    );
    expect(find.text('Kollektiv Wolkenwinkel'), findsNothing);
    await tester.tap(find.text('Suche zurücksetzen'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.ensureVisible(find.byTooltip('Menü'));
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Communities'));
    await tester.tap(find.text('Communities'));
    await tester.pumpAndSettle();
    expect(
      find.text('Die Communityübersicht ist noch nicht angebunden.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Über'));
    await tester.pumpAndSettle();
    expect(find.text('Entdecken.\nKennenlernen.\nDabei sein.'), findsOneWidget);
  });

  testWidgets(
    'account recovery link bypasses discovery and keeps home return',
    (tester) async {
      await tester.pumpWidget(
        CommunityAccessApp(
          api: AuthAccountApi(),
          authOnly: true,
          showPublicHome: true,
          initialAccountLink: const AccountLinkData('forgot'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AccountRecoveryPage), findsOneWidget);
      expect(find.text('Events & Communities.'), findsNothing);
      final context = tester.element(find.byType(AccountRecoveryPage));
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zur Hauptseite'));
      await tester.pumpAndSettle();
      expect(find.text('Events & Communities.'), findsOneWidget);
      await tester.tap(find.text('Anmelden'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountRecoveryPage), findsNothing);
    },
  );

  testWidgets('public entry fits narrow viewport with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CommunityAccessApp(
        api: AuthAccountApi(),
        authOnly: true,
        showPublicHome: true,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Events & Communities.'));
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: CommunityAccessApp(
          api: AuthAccountApi(),
          authOnly: true,
          showPublicHome: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Konto').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
