import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/directory_api.dart';
import 'package:community_access_client/event_interest_panel.dart';
import 'package:community_access_client/event_editorial_view.dart';
import 'package:community_access_client/organizer_management_page.dart';

import 'field_finder.dart';

import 'package:community_access_client/event_datetime_field.dart';

class DeadlineFixture implements DirectoryApi {
  String? requestStatus;
  bool open = true;
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    if (body != null) {
      writes.add({'path': path, ...body});
      if (path.endsWith('/interest')) requestStatus = 'pending';
      if (path.endsWith('/withdraw')) requestStatus = 'withdrawn';
      return {};
    }
    return {
      'signed_in': true,
      'method': 'manual',
      'form': [],
      'before_start': null,
      'can_request': open,
      'can_withdraw': open && requestStatus == 'pending',
      'can_visit': false,
      'request_deadline_at': '2026-11-06T18:00:00Z',
      'request': requestStatus == null ? null : {'status': requestStatus},
    };
  }
}

Future<void> render(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AccessDesign.theme(),
      home: Scaffold(body: SingleChildScrollView(child: widget)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'published deadline enables request and withdrawal without exposing a begin',
    (tester) async {
      final api = DeadlineFixture();
      await render(
        tester,
        EventInterestPanel(api: api, id: 'demo', onChanged: () {}),
      );
      expect(find.textContaining('Öffentliche Anfragefrist:'), findsOneWidget);
      expect(find.text('Ich war dort'), findsNothing);
      await tester.tap(find.text('Interesse bekunden'));
      await tester.pumpAndSettle();
      expect(api.writes.last['path'], 'events/demo/interest');
      expect(find.text('Teilnahme zurückziehen'), findsOneWidget);
      await tester.tap(find.text('Teilnahme zurückziehen'));
      await tester.pumpAndSettle();
      expect(api.writes.last['path'], 'events/demo/withdraw');
      api.open = false;
      await render(
        tester,
        EventInterestPanel(
          key: const ValueKey('closed'),
          api: api,
          id: 'demo',
          onChanged: () {},
        ),
      );
      expect(find.text('Anfragen sind derzeit geschlossen.'), findsOneWidget);
      final button = tester.widget<AccessAction>(
        find.widgetWithText(AccessAction, 'Interesse bekunden'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Teilnahme zurückziehen'), findsNothing);
    },
  );
  testWidgets(
    'editor preserves an explicit public deadline separately from hidden times',
    (tester) async {
      final api = DeadlineFixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: EventDirectoryEditor(
            api: api,
            communities: const [
              {'id': 'community', 'name': 'Demo Community'},
            ],
            profileId: 'profile',
            profilePublic: true,
            event: const {
              'id': 'event',
              'version': 1,
              'title': 'Demo geschützter Abend',
              'community_id': 'community',
              'status': 'draft',
              'access_mode': 'semi_public',
              'request_deadline_at': '2026-11-06T18:00:00Z',
              'starts_at': '2026-11-07T23:00:00Z',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final deadline = find.byWidgetPredicate(
        (w) => w is EventDateTimeField && w.label == 'Öffentliche Anfragefrist',
      );
      await tester.ensureVisible(deadline);
      expect(
        tester.widget<EventDateTimeField>(deadline).controller.text,
        '2026-11-06T18:00:00Z',
      );
      await tester.enterText(
        fieldWithLabel(TextField, 'Öffentliche Anfragefrist: Datum'),
        '06.11.2026',
      );
      await tester.enterText(
        fieldWithLabel(TextField, 'Öffentliche Anfragefrist: Uhrzeit'),
        '16:00',
      );
      await tester.ensureVisible(find.text('Eventangaben speichern'));
      await tester.tap(find.text('Eventangaben speichern'));
      await tester.pumpAndSettle();
      expect(
        api.writes.single['request_deadline_at'],
        DateTime(2026, 11, 6, 16).toUtc().toIso8601String(),
      );
      expect(api.writes.single['starts_at'], '2026-11-07T23:00:00Z');
    },
  );
  testWidgets(
    'public deadline appears while protected start and venue remain absent',
    (tester) async {
      await render(
        tester,
        const EventEditorialView(
          event: {
            'title': 'Demo geschützter Abend',
            'starts_at': null,
            'location': '',
            'request_deadline_at': '2026-11-06T18:00:00Z',
            'event_content': {},
          },
        ),
      );
      expect(find.text('Öffentliche Anfragefrist'), findsOneWidget);
      expect(find.text('Wird bekannt gegeben'), findsOneWidget);
      expect(find.text('Noch nicht freigegeben'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
