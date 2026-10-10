import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/ticketing_api.dart';
import 'package:community_access_client/ticketing_pages.dart';
import 'package:community_access_client/design_system.dart';

class TicketFixture implements TicketingApi {
  bool paid = false;
  bool eligible = true;
  final writes = <Map<String, dynamic>>[];
  Map<String, dynamic> get order => {
    'id': 'order',
    'event_id': 'event',
    'state': paid ? 'paid' : 'pending',
    'blocked': false,
    'total_cents': 1250,
    'fee_cents': 63,
    'fee_version': 1,
    'refunded_cents': 0,
    'fee_refunded_cents': 0,
    'synthetic': true,
    'event_title': 'Demo Ticketabend',
  };
  @override
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (body != null) writes.add({'path': path, ...body});
    if (path.endsWith('/offer')) {
      return {
        'mode': 'public',
        'item_name': 'Demo Eintritt',
        'price_cents': 1250,
        'seller': 'Demo Veranstalter',
        'available': 1,
        'can_buy': eligible,
        'minimum_age': 18,
        'synthetic': true,
      };
    }
    if (path == 'mine') {
      return {
        'items': paid ? [order] : [],
      };
    }
    if (path.endsWith('/simulate')) {
      paid = body!['outcome'] == 'success';
      return order;
    }
    if (path.endsWith('/ticket')) {
      return {
        'ticket': {'id': 'order', 'admission': 'Eine Person'},
      };
    }
    if (path.endsWith('/connection')) {
      return {'connected': true, 'synthetic': true};
    }
    if (path.endsWith('/refunds')) return {'items': []};
    if (path.endsWith('/config')) return {'mode': 'none', 'version': 0};
    if (path == 'fee') return {'fee': null};
    return order;
  }
}

void main() {
  for (final expired in [false, true]) {
    testWidgets('reopening account verifies shared session, expired=$expired', (
      tester,
    ) async {
      final api = BetterAuthAccessApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/sign-in/email') {
            return http.Response(
              '{}',
              200,
              headers: {'set-auth-token': 'synthetic-session'},
            );
          }
          if (request.url.path == '/api/account/me') {
            return expired
                ? http.Response('{}', 401)
                : http.Response(
                    jsonEncode({
                      'user': {
                        'name': 'Demo Gast',
                        'email': 'guest@example.invalid',
                        'email_verified': true,
                      },
                      'ticketing_available': true,
                      'preferences_configured': true,
                      'product_available': false,
                      'directory_available': false,
                      'applications': [],
                      'memberships': [],
                      'events': [],
                    }),
                    200,
                  );
          }
          return http.Response('{"providers":[]}', 200);
        }),
      );
      await api.login('guest@example.invalid', 'Synthetic-2026!');
      await tester.pumpWidget(CommunityAccessApp(api: api, authOnly: true));
      await tester.pumpAndSettle();
      expect(
        find.text('Meine Tickets'),
        expired ? findsNothing : findsOneWidget,
      );
      expect(api.hasSession, !expired);
      if (expired) {
        expect(find.textContaining('Sitzung ist abgelaufen'), findsOneWidget);
      }
    });
  }
  testWidgets(
    'age acknowledgment gates checkout; simulation alone goes through API and refreshes',
    (tester) async {
      final api = TicketFixture();
      int changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TicketPurchasePanel(
                api: api,
                eventId: 'event',
                onChanged: () => changes++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Verkäufer: Demo Veranstalter'), findsOneWidget);
      final button = find.widgetWithText(AccessAction, 'Eigenes Ticket kaufen');
      expect(tester.widget<AccessAction>(button).onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eigenes Ticket kaufen'));
      await tester.pumpAndSettle();
      expect(api.writes.single['age_acknowledged'], true);
      expect(
        find.text('Synthetische Zahlung · es wird kein Geld bewegt'),
        findsOneWidget,
      );
      await tester.tap(find.text('Erfolgreiche Testzahlung'));
      await tester.pumpAndSettle();
      expect(find.text('Bezahlt · Teilnahme bestätigt'), findsOneWidget);
      await tester.tap(find.text('Zurück zum Event'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(tester.widget<AccessAction>(button).onPressed, isNull);
    },
  );
  testWidgets('a backend denial cannot be bypassed with the age checkbox', (
    tester,
  ) async {
    final api = TicketFixture()..eligible = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketPurchasePanel(
            api: api,
            eventId: 'event',
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AccessAction>(
            find.widgetWithText(AccessAction, 'Eigenes Ticket kaufen'),
          )
          .onPressed,
      isNull,
    );
    expect(api.writes, isEmpty);
  });
  testWidgets(
    'ticket documents are fetched separately and show a synthetic proof',
    (tester) async {
      final api = TicketFixture()..paid = true;
      await tester.pumpWidget(MaterialApp(home: MyTicketsPage(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Demo Ticketabend'), findsOneWidget);
      await tester.tap(find.text('Ticket anzeigen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Testbeleg · kein gültiges Eintrittsticket'),
        findsOneWidget,
      );
      expect(find.text('Eine Person'), findsOneWidget);
    },
  );
  testWidgets(
    'provision starts empty and rejects invalid rates before a write',
    (tester) async {
      final api = TicketFixture();
      await tester.pumpWidget(MaterialApp(home: TicketFeePage(api: api)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('Provision speichern'));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      await tester.enterText(find.byType(TextField), '2,75');
      await tester.tap(find.text('Provision speichern'));
      await tester.pumpAndSettle();
      expect(api.writes.single['basis_points'], 275);
    },
  );
  for (final size in [const Size(320, 900), const Size(768, 900)]) {
    testWidgets('ticket pages fit $size at doubled text', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = TicketFixture()..paid = true;
      for (final page in [
        MyTicketsPage(api: api),
        TicketCheckoutPage(api: api, initialOrder: api.order),
        TicketingManagementPage(
          api: api,
          profileId: 'profile',
          events: const [
            {'id': 'event', 'title': 'Demo Ticketabend'},
          ],
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
