import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/better_auth_api.dart';
import 'package:community_access_client/resource_return.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/site_information_page.dart';
import 'package:community_access_client/ticketing_api.dart';
import 'package:community_access_client/ticketing_pages.dart';

class DeniedResourceApi implements DirectoryApi {
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async => throw const ApiFailure(
    'Dieser Eintrag ist nicht verfügbar oder nicht für dich freigegeben.',
    accessDenied: true,
  );
}

class ReceiptFixture implements TicketingApi {
  bool expired = false;
  @override
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (expired) {
      throw const ApiFailure('Session expired', unauthenticated: true);
    }
    if (path != 'mine') {
      throw const ApiFailure('Platform blocked', accessDenied: true);
    }
    return {
      'items': [
        {
          'id': 'synthetic-order',
          'event_id': 'synthetic-event',
          'event_title': 'Synthetic receipt',
          'state': 'paid',
          'total_cents': 1250,
          'refunded_cents': 0,
          'blocked': false,
        },
      ],
    };
  }
}

void main() {
  test(
    'registration never adopts a signed or raw token from the response',
    () async {
      final api = BetterAuthAccessApi(
        client: MockClient(
          (_) async => http.Response(
            '{"token":"raw","registration_requested":true}',
            200,
            headers: {'set-auth-token': 'unexpected-session'},
          ),
        ),
      );
      await api.createAccount(
        'Synthetic',
        'synthetic@example.invalid',
        'Synthetic-2026!',
      );
      expect(api.hasSession, false);
      api.close();
    },
  );
  test('snapshot restores only a signed response header and logout sends a revocation request', () async {
    final seen = <String>[];
    final api = BetterAuthAccessApi(
      client: MockClient((request) async {
        seen.add(request.url.path);
        return http.Response(
          '{}',
          200,
          headers: request.url.path == '/api/account/me'
              ? {'set-auth-token': 'cookie-validated-signed-session'}
              : {},
        );
      }),
    );
    expect(api.hasSession, false);
    await api.snapshot();
    expect(api.hasSession, true);
    await api.logout();
    expect(api.hasSession, false);
    expect(seen.last, '/api/auth/sign-out');
    api.close();
  });
  test('legal codes reach the intended messages and platform denial retains its flag', () async {
    for (final item in {
      'LEGAL_SALES_PAUSED': 'Ticketverkauf zur Klärung pausiert',
      'STATEMENT_EXISTS': 'Deine Stellungnahme wurde bereits eingereicht.',
      'PLATFORM_BLOCKED': 'Dein Konto ist für Plattformaktionen gesperrt. Eigene Bestellbelege und Beschwerden bleiben erreichbar.',
    }.entries) {
      final api = BetterAuthAccessApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'code': item.key,
              'private_details': 'must never appear',
            }),
            403,
          ),
        ),
      );
      await expectLater(
        api.legal('mine'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.message, 'message', item.value)
              .having((e) => e.accessDenied, 'denied', true),
        ),
      );
      api.close();
    }
  });
  test('resource return accepts only one event or series UUID, never tokens or redirects', () {
    const id = '12345678-1234-1234-1234-123456789abc';
    expect(validatedResourceTarget('event=$id'), {'kind': 'event', 'id': id});
    expect(validatedResourceTarget('series=$id'), {'kind': 'series', 'id': id});
    for (final value in [
      'event=$id&event=$id',
      'event=$id&token=secret',
      'redirect=https://example.invalid',
      'event=../../secret',
      'verify=${'a' * 64}&email=synthetic@example.invalid',
    ]) {
      expect(validatedResourceTarget(value), null);
    }
  });
  testWidgets(
    'unavailable return target offers neutral reauthentication without revealing event content',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ProgramDetailPage(
            api: DeniedResourceApi(),
            kind: 'events',
            id: '12345678-1234-1234-1234-123456789abc',
            openAccount: () async {
              calls++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anmelden und Zugriff erneut prüfen'), findsOneWidget);
      expect(find.text('Eigenes Ticket kaufen'), findsNothing);
      await tester.tap(find.text('Anmelden und Zugriff erneut prüfen'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
  testWidgets(
    'blocked accounts retain receipts without admission actions, expiry removes loaded receipts',
    (tester) async {
      final api = ReceiptFixture();
      await tester.pumpWidget(
        MaterialApp(home: MyTicketsPage(api: api, receiptsOnly: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic receipt'), findsOneWidget);
      expect(find.text('Ticket anzeigen'), findsNothing);
      expect(find.text('Online-Einlasscode anzeigen'), findsNothing);
      api.expired = true;
      await tester.tap(find.text('Tickets neu laden'));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic receipt'), findsNothing);
      expect(find.text('Session expired'), findsOneWidget);
    },
  );
  testWidgets('English recovery and bounded retry copy are translated', (
    tester,
  ) async {
    final language = AppLanguage()..value = true;
    await tester.pumpWidget(
      LanguageScope(
        language: language,
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LocalText(
                  'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
                ),
                LocalText(
                  'Zu viele Anfragen. Bitte warte 45 Sekunden und versuche es erneut.',
                ),
                LocalText(
                  'Der Link gilt 60 Minuten und kann einmal verwendet werden.',
                ),
                SiteInformationLinks(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Your session expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(
      find.text('Too many requests. Please wait 45 seconds and try again.'),
      findsOneWidget,
    );
    expect(
      find.text('The link is valid for 60 minutes and can be used once.'),
      findsOneWidget,
    );
    expect(find.text('Legal notice'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Help & contact'), findsOneWidget);
    language.dispose();
  });
}
