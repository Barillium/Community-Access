import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/access_flow_api.dart';
import 'package:community_access_client/private_ticket_pages.dart';
import 'package:community_access_client/private_access_management_page.dart';
import 'package:community_access_client/ticketing_api.dart';
import 'package:community_access_client/ticketing_pages.dart';

class TestPrivateApi implements TicketingApi, AccessFlowApi {
  final calls = <String>[];
  bool failScan = false;
  bool nativeWallet = false;
  Completer<Map<String, dynamic>>? catalog;
  @override
  Future<Map<String, dynamic>> ticketing(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (catalog != null) return catalog!.future;
    if (nativeWallet && path == 'mine') {
      return {
        'items': [
          {
            'id': 'order',
            'state': 'paid',
            'blocked': false,
            'native_pretix': true,
            'total_cents': 1000,
            'refunded_cents': 0,
          },
        ],
      };
    }
    if (nativeWallet && path.endsWith('/ticket')) {
      return {
        'ticket': {'native_pretix': true, 'admission': 'Eine Person'},
      };
    }
    return {
      'items': [
        {
          'id': 'type',
          'name': 'Synthetisches Angebot',
          'price_cents': 1000,
          'can_buy': false,
          'purchase_rule': 'event_approval_required',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (path.endsWith('/token')) return {'token': 'synthetic-online-code'};
    if (path == 'policy/scanner-events') {
      return {
        'items': [
          {'id': 'event', 'title': 'Synthetischer Abend'},
        ],
      };
    }
    if (failScan) throw const ApiFailure('Einlass abgewiesen.');
    return {'checked_in': true, 'synthetic': true};
  }
}

class WorkspaceApi implements AccessFlowApi {
  final bool moderator;
  Completer<Map<String, dynamic>>? pending;
  WorkspaceApi({this.moderator = false});
  @override
  Future<Map<String, dynamic>> access(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    if (pending != null) return pending!.future;
    return {
      'events': [],
      'profiles': [],
      'communities': [
        {
          'id': 'community',
          'name': 'Synthetische Community',
          'moderator': moderator,
        },
      ],
      'cases': [],
      'rules': [],
      'publisher_profiles': [],
      'publication_targets': [],
      'publication_requests': [],
      'restrictions': [],
      'is_team': false,
    };
  }
}

void main() {
  testWidgets('English moderation translates actions and input labels', (
    tester,
  ) async {
    final language = AppLanguage()..value = true;
    addTearDown(language.dispose);
    await tester.pumpWidget(
      LanguageScope(
        language: language,
        child: MaterialApp(
          home: PrivateAccessManagementPage(api: WorkspaceApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Approvals and moderation'), findsOneWidget);
    expect(find.text('Verified account email'), findsOneWidget);
    expect(find.text('Pause community access for 24 hours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'native wallet exposes platform online code without opening checkout',
    (tester) async {
      final api = TestPrivateApi()..nativeWallet = true;
      await tester.pumpWidget(MaterialApp(home: MyTicketsPage(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online-Einlasscode anzeigen'));
      await tester.pumpAndSettle();
      expect(find.text('synthetic-online-code'), findsOneWidget);
      expect(api.calls, contains('policy/orders/order/token'));
      expect(api.calls.where((path) => path.contains('handoff')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing approval leaves category purchase disabled at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = TestPrivateApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrivateTicketCategories(
                api: api,
                eventId: 'event',
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetisches Angebot · 10,00 €'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Dieses Ticket kaufen'),
            )
            .onPressed,
        isNull,
      );
      expect(api.calls.where((p) => p.contains('checkout')), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('switching API discards private catalog and its late response', (
    tester,
  ) async {
    final old = TestPrivateApi()..catalog = Completer<Map<String, dynamic>>();
    final next = TestPrivateApi();
    Widget app(TestPrivateApi api) => MaterialApp(
      home: Scaffold(
        body: PrivateTicketCategories(
          api: api,
          eventId: 'event',
          onChanged: () {},
        ),
      ),
    );
    await tester.pumpWidget(app(old));
    await tester.pumpWidget(app(next));
    await tester.pumpAndSettle();
    old.catalog!.complete({
      'items': [
        {'name': 'Alter privater Inhalt', 'id': 'old'},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Alter privater Inhalt'), findsNothing);
    expect(find.text('Synthetisches Angebot · 10,00 €'), findsOneWidget);
  });
  testWidgets(
    'publisher without moderator scope cannot start community administration',
    (tester) async {
      final api = WorkspaceApi();
      await tester.pumpWidget(
        MaterialApp(home: PrivateAccessManagementPage(api: api)),
      );
      await tester.pumpAndSettle();
      final dropdown = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Zuständige Community',
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetische Community').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(
                OutlinedButton,
                'Communityzugang für 24 h pausieren',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Moderationsfall anlegen'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Moderationsfall anlegen'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late moderation workspace is discarded after changing account API',
    (tester) async {
      final old = WorkspaceApi()..pending = Completer<Map<String, dynamic>>();
      final next = WorkspaceApi();
      Widget app(WorkspaceApi api) =>
          MaterialApp(home: PrivateAccessManagementPage(api: api));
      await tester.pumpWidget(app(old));
      await tester.pumpWidget(app(next));
      await tester.pumpAndSettle();
      old.pending!.complete({
        'events': [
          {'id': 'old', 'title': 'Alter privater Moderationsinhalt'},
        ],
        'communities': [],
        'cases': [],
        'is_team': true,
      });
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Alter privater Moderationsinhalt'),
        findsNothing,
      );
      expect(find.text('Moderation für 24 h zuweisen'), findsNothing);
    },
  );
  testWidgets('failed online admission never shows success', (tester) async {
    final api = TestPrivateApi()..failScan = true;
    await tester.pumpWidget(MaterialApp(home: OnlineCheckinPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetischer Abend').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'synthetic-ticket-token',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'guest@example.invalid',
    );
    await tester.tap(find.text('Einlass online prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Einlass abgewiesen.'), findsOneWidget);
    expect(find.text('Einlass bestätigt · synthetischer Test'), findsNothing);
    expect(api.calls.last, 'policy/events/event/checkin');
  });
}
