import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:community_access_client/ticketing_checkout_bridge.dart';

import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/access_flow_api.dart';
import 'package:community_access_client/account_complaints_page.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/legal_api.dart';
import 'package:community_access_client/legal_pages.dart';
import 'package:community_access_client/private_ticket_pages.dart';
import 'package:community_access_client/ticketing_api.dart';
import 'package:community_access_client/ticketing_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Reply = Future<Map<String, dynamic>> Function(
  String path,
  Map<String, dynamic>? body,
);

class PathsApi implements TicketingApi, LegalApi, AccessFlowApi {
  final Reply ticket, law, policy;
  PathsApi({Reply? ticket, Reply? law, Reply? policy})
    : ticket = ticket ?? empty,
      law = law ?? empty,
      policy = policy ?? empty;
  static Future<Map<String, dynamic>> empty(
    String path,
    Map<String, dynamic>? body,
  ) async => {'items': [], 'cases': []};
  @override
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  }) => ticket(path, body);
  @override
  Future<Map<String, dynamic>> legal(
    String path, {
    Map<String, dynamic>? body,
  }) => law(path, body);
  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) => policy(path, body);
}

class RevisionApi extends PathsApi implements TicketingSessionContext {
  @override
  int sessionRevision = 1;
  RevisionApi({Reply? ticket, super.law, super.policy})
    : super(ticket: ticket ?? (path, body) async => {'code': 'synthetic-code'});
}

const receipt = {
  'id': 'order',
  'event_id': 'event',
  'event_title': 'Synthetic receipt',
  'state': 'paid',
  'blocked': false,
  'total_cents': 1000,
  'refunded_cents': 0,
  'seller_snapshot': {
    'legal_name': 'Synthetic seller',
    'address': 'Synthetic address',
    'contact': 'seller@example.invalid',
    'seller_status': 'private',
  },
};

Future<void> pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(theme: AccessDesign.theme(), home: page));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('private category becomes usable after returning from checkout', (
    tester,
  ) async {
    var changes = 0;
    final api = PathsApi(
      ticket: (path, body) async {
        if (path.endsWith('/checkout')) return {...receipt, 'state': 'pending'};
        return {
          'items': [
            {
              'id': 'type',
              'name': 'Synthetic category',
              'price_cents': 1000,
              'can_buy': true,
            },
          ],
        };
      },
    );
    await pump(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: PrivateTicketCategories(
            api: api,
            eventId: 'event',
            onChanged: () => changes++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tap(tester, 'Dieses Ticket kaufen');
    await tap(tester, 'Zurück zum Event');
    expect(changes, 1);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Dieses Ticket kaufen'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'an old event checkout response cannot open a different event order',
    (tester) async {
      final checkout = Completer<Map<String, dynamic>>();
      final api = PathsApi(
        ticket: (path, body) async {
          if (path.endsWith('/checkout')) return checkout.future;
          if (path == 'mine') return {'items': []};
          return {
            'can_buy': true,
            'item_name': 'Synthetic offer',
            'price_cents': 1000,
            'available': 2,
            'seller': 'Synthetic seller',
          };
        },
      );
      Widget page(String event) => Scaffold(
        body: SingleChildScrollView(
          child: TicketPurchasePanel(
            api: api,
            eventId: event,
            onChanged: () {},
          ),
        ),
      );
      await pump(tester, page('event-a'));
      await tester.tap(find.text('Eigenes Ticket kaufen'));
      await tester.pump();
      await pump(tester, page('event-b'));
      checkout.complete({
        ...receipt,
        'event_id': 'event-a',
        'state': 'pending',
      });
      await tester.pumpAndSettle();
      expect(find.text('Ticketbestellung'), findsNothing);
      expect(
        tester
            .widget<AccessAction>(
              find.widgetWithText(AccessAction, 'Eigenes Ticket kaufen'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'ticket display is single flight and denial retains own receipt only',
    (tester) async {
      final ticket = Completer<Map<String, dynamic>>();
      var calls = 0;
      final api = PathsApi(
        ticket: (path, body) async {
          if (path == 'mine') {
            return {
              'items': [receipt],
            };
          }
          if (path.endsWith('/ticket')) {
            calls++;
            return ticket.future;
          }
          return {};
        },
      );
      await pump(tester, MyTicketsPage(api: api));
      await tester.ensureVisible(find.text('Ticket anzeigen'));
      await tester.tap(find.text('Ticket anzeigen'));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Ticket anzeigen'),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      ticket.completeError(
        const ApiFailure('Synthetic access denied', accessDenied: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic receipt'), findsOneWidget);
      expect(find.text('Ticket anzeigen'), findsNothing);
      expect(find.text('Synthetic access denied'), findsOneWidget);
    },
  );

  testWidgets(
    'an expired checkout identity removes private receipt and active payment actions',
    (tester) async {
      final api = PathsApi(
        ticket: (path, body) async => throw const ApiFailure(
          'Synthetic session expired',
          unauthenticated: true,
        ),
      );
      await pump(
        tester,
        TicketCheckoutPage(
          api: api,
          initialOrder: {...receipt, 'state': 'pending', 'synthetic': true},
        ),
      );
      expect(find.text('Synthetic seller'), findsOneWidget);
      await tap(tester, 'Zahlungsstatus prüfen');
      expect(find.text('Synthetic seller'), findsNothing);
      expect(find.text('Erfolgreiche Testzahlung'), findsNothing);
      expect(find.text('Synthetic session expired'), findsOneWidget);
    },
  );

  testWidgets(
    'seller save does not replace a denied refresh with success or retain address',
    (tester) async {
      var written = false;
      final api = PathsApi(
        ticket: (path, body) async {
          if (body != null) {
            written = true;
            return {};
          }
          if (written) {
            throw const ApiFailure(
              'Synthetic seller denied',
              accessDenied: true,
            );
          }
          return {
            'can_edit': true,
            'seller': {
              'legal_name': 'Synthetic seller',
              'address': 'Synthetic address',
              'contact': 'seller@example.invalid',
              'seller_status': 'private',
              'version': 1,
            },
          };
        },
      );
      await pump(tester, SellerManagementPage(api: api, profileId: 'profile'));
      await tap(tester, 'Verkäuferangaben speichern');
      expect(find.text('Synthetic seller denied'), findsOneWidget);
      expect(
        find.textContaining('Verkäuferangaben gespeichert.'),
        findsNothing,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Verkäuferangaben speichern'),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'declaration save preserves reload denial and removes stale seller',
    (tester) async {
      var written = false;
      final api = PathsApi(
        ticket: (path, body) async {
          if (body != null) {
            written = true;
            return {};
          }
          if (written) {
            throw const ApiFailure(
              'Synthetic declaration denied',
              accessDenied: true,
            );
          }
          return {
            'seller': receipt['seller_snapshot'],
            'terms_version': legalDeclarationVersion,
            'event_version': 1,
            'seller_version': 1,
          };
        },
      );
      await pump(tester, EventDeclarationPage(api: api, eventId: 'event'));
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tap(tester, 'Bestätigung speichern');
      expect(find.text('Synthetic declaration denied'), findsOneWidget);
      expect(find.text('Bestätigung gespeichert.'), findsNothing);
      expect(find.text('Synthetic seller'), findsNothing);
    },
  );

  testWidgets(
    'legal list refresh clears old private rows and prevents duplicate reads',
    (tester) async {
      final reload = Completer<Map<String, dynamic>>();
      var reads = 0;
      final api = PathsApi(
        law: (path, body) async {
          reads++;
          if (reads > 1) return reload.future;
          return {
            'items': [
              {
                'id': 'report',
                'reference': 'Synthetic private reference',
                'status': 'open',
              },
            ],
          };
        },
      );
      await pump(tester, LegalReviewsPage(api: api, team: true));
      await tester.tap(find.text('Aktualisieren'));
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Aktualisieren'),
            )
            .onPressed,
        isNull,
      );
      reload.completeError(
        const ApiFailure('Synthetic team denied', accessDenied: true),
      );
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Synthetic private reference'), findsNothing);
    },
  );

  testWidgets('own legal detail revalidates the navigation snapshot', (
    tester,
  ) async {
    var reads = 0;
    final api = PathsApi(
      law: (path, body) async {
        expect(path, 'mine');
        reads++;
        return {'items': []};
      },
    );
    await pump(
      tester,
      LegalReviewDetailPage(
        api: api,
        item: const {
          'id': 'action',
          'reason': 'Stale private reason',
          'action': 'sales_paused',
        },
        team: false,
      ),
    );
    expect(reads, 1);
    expect(find.text('Stale private reason'), findsNothing);
    expect(find.text('Erneute Prüfung anfordern'), findsNothing);
  });

  testWidgets(
    'complaints distinguish loading from empty and validate a repeated submission',
    (tester) async {
      final initial = Completer<Map<String, dynamic>>();
      var writes = 0;
      final api = PathsApi(
        policy: (path, body) async {
          if (body == null) return initial.future;
          writes++;
          return {'submitted': true, 'already_submitted': true};
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: AccountComplaintsPage(api: api)),
      );
      await tester.pump();
      expect(
        find.text('Keine eigenen Moderationsfälle vorhanden.'),
        findsNothing,
      );
      initial.complete({
        'cases': [
          {'id': 'synthetic-case', 'created_at': '2026-10-09T12:00:00Z'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('synthetic-case'), findsOneWidget);
      await tap(tester, 'Erneute Prüfung verlangen');
      await tap(tester, 'Einreichen');
      expect(find.text('Bitte ausfüllen.'), findsOneWidget);
      expect(writes, 0);
      await tester.enterText(
        find.byType(TextFormField),
        'Synthetic own complaint',
      );
      await tap(tester, 'Einreichen');
      expect(writes, 1);
      expect(find.text('Beschwerde bereits eingereicht.'), findsWidgets);
      expect(find.text('Erneute Prüfung verlangen'), findsNothing);
    },
  );

  testWidgets(
    'scanner refuses empty inputs and clears credentials after confirmed admission',
    (tester) async {
      var writes = 0;
      final api = PathsApi(
        policy: (path, body) async {
          if (body == null) {
            return {
              'items': [
                {'id': 'event', 'title': 'Synthetic event'},
              ],
            };
          }
          writes++;
          return {'checked_in': true};
        },
      );
      await pump(tester, OnlineCheckinPage(api: api));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic event').last);
      await tester.pumpAndSettle();
      await tap(tester, 'Einlass online prüfen');
      expect(writes, 0);
      expect(
        find.text('Bitte Ticketcode und Konto-E-Mail eingeben.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byType(TextField).at(0),
        'synthetic-ticket-code',
      );
      await tester.enterText(
        find.byType(TextField).at(1),
        'guest@example.invalid',
      );
      await tap(tester, 'Einlass online prüfen');
      expect(writes, 1);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, isEmpty);
      }
      expect(
        find.text('Einlass bestätigt · synthetischer Test'),
        findsOneWidget,
      );
    },
  );
  test('native entry response cannot return an old checkout after identity changes', () async {
    final api = RevisionApi();
    final started = Completer<void>();
    final entry = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          '{"browser_nonce":"synthetic-browser-nonce"}',
          200,
        );
      }
      started.complete();
      return entry.future;
    });
    addTearDown(client.close);
    final checkout = prepareNativeTicketCheckout(api, {
      'id': 'synthetic-order',
      'native_checkout_entry':
          'http://127.0.0.1:8400/demo/event/community-access/entry/',
    }, client: client);
    await started.future;
    api.sessionRevision++;
    entry.complete(
      http.Response(
        '{"checkout_url":"/demo/event/checkout/synthetic-private-path"}',
        200,
      ),
    );
    await expectLater(
      checkout,
      throwsA(
        isA<ApiFailure>().having(
          (error) => error.accessDenied,
          'access denied',
          true,
        ),
      ),
    );
  });
  testWidgets(
    'receipts-only view never asks for an admission token or native handoff',
    (tester) async {
      final calls = <String>[];
      final api = PathsApi(
        ticket: (path, body) async {
          calls.add(path);
          return {
            'items': [
              {...receipt, 'native_pretix': true},
            ],
          };
        },
        policy: (path, body) async {
          fail('No active admission action permitted in receipts-only view');
        },
      );
      await pump(tester, MyTicketsPage(api: api, receiptsOnly: true));
      expect(find.text('Synthetic receipt'), findsOneWidget);
      expect(find.text('Ticket anzeigen'), findsNothing);
      expect(find.text('Online-Einlasscode anzeigen'), findsNothing);
      expect(calls, ['mine']);
    },
  );

  testWidgets(
    'confirmed existing own appeal displays dates and cannot be submitted again',
    (tester) async {
      final api = PathsApi(
        policy: (path, body) async {
          expect(body, isNull);
          return {
            'cases': [
              {
                'id': 'synthetic-own-case',
                'created_at': '2026-10-08T12:00:00Z',
                'appeal_submitted': true,
                'appeal_submitted_at': '2026-10-09T12:00:00Z',
              },
            ],
          };
        },
      );
      await pump(tester, AccountComplaintsPage(api: api));
      expect(find.text('synthetic-own-case'), findsOneWidget);
      expect(find.text('2026-10-08'), findsOneWidget);
      expect(find.text('2026-10-09'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Beschwerde bereits eingereicht.',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'offer and wallet cannot be combined across completed-request identity changes',
    (tester) async {
      late RevisionApi api;
      var mineReads = 0;
      api = RevisionApi(
        ticket: (path, body) async {
          if (path.endsWith('/offer')) {
            // The old request has completed; the next request would use a new identity.
            api.sessionRevision++;
            return {'seller': 'Old private seller', 'can_buy': true};
          }
          mineReads++;
          return {'items': []};
        },
      );
      await pump(
        tester,
        Scaffold(
          body: TicketPurchasePanel(
            api: api,
            eventId: 'event',
            onChanged: () {},
          ),
        ),
      );
      expect(mineReads, 0);
      expect(find.textContaining('Old private seller'), findsNothing);
      expect(find.text('Eigenes Ticket kaufen'), findsNothing);
      expect(
        find.text(
          'Die Sitzung wurde geändert. Bitte lade den aktuellen Stand erneut.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'organizer connection and refunds cannot be combined across identities',
    (tester) async {
      late RevisionApi api;
      var readsAfterChange = 0;
      api = RevisionApi(
        ticket: (path, body) async {
          if (path.endsWith('/connection')) {
            api.sessionRevision++;
            return {'connected': true, 'can_manage_connection': true};
          }
          readsAfterChange++;
          return {'items': []};
        },
      );
      await pump(
        tester,
        TicketingManagementPage(
          api: api,
          profileId: 'profile',
          events: const [
            {'id': 'event', 'title': 'Old private managed event'},
          ],
        ),
      );
      expect(readsAfterChange, 0);
      expect(find.text('Old private managed event'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Stripe-Testverbindung simulieren',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'switching complaint API discards late own cases from the old account',
    (tester) async {
      final oldLoad = Completer<Map<String, dynamic>>();
      final old = PathsApi(policy: (path, body) => oldLoad.future);
      final next = PathsApi(
        policy: (path, body) async => {
          'cases': [
            {'id': 'new-own-case'},
          ],
        },
      );
      await tester.pumpWidget(
        MaterialApp(home: AccountComplaintsPage(api: old)),
      );
      await tester.pump();
      await pump(tester, AccountComplaintsPage(api: next));
      oldLoad.complete({
        'cases': [
          {'id': 'old-private-case'},
        ],
      });
      await tester.pumpAndSettle();
      expect(find.text('new-own-case'), findsOneWidget);
      expect(find.text('old-private-case'), findsNothing);
    },
  );

  testWidgets(
    'complaint dialog cannot submit after the starting identity changes',
    (tester) async {
      var writes = 0;
      final api = RevisionApi(
        policy: (path, body) async {
          if (body != null) {
            writes++;
            return {'submitted': true};
          }
          return {
            'cases': [
              {'id': 'synthetic-case'},
            ],
          };
        },
      );
      await pump(tester, AccountComplaintsPage(api: api));
      await tap(tester, 'Erneute Prüfung verlangen');
      await tester.enterText(
        find.byType(TextFormField),
        'Old account complaint',
      );
      api.sessionRevision++;
      await tap(tester, 'Einreichen');
      expect(writes, 0);
      expect(find.text('synthetic-case'), findsNothing);
      expect(
        find.text(
          'Die Sitzung wurde geändert. Bitte lade den aktuellen Stand erneut.',
        ),
        findsOneWidget,
      );
    },
  );
}
