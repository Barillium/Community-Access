import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/access_api.dart';
import 'package:community_access_client/bookmark_views.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/design_system.dart';

import 'program_widget_test.dart';

class InterestFixture extends ProgramFixture {
  int count = 0;
  bool saved = false, failWrite = false, public = true, loggedIn = true;
  @override
  Future<Map<String, dynamic>> directory(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    calls.add(path);
    if (path == 'bookmarks') {
      return {
        'profiles': [],
        'series': [],
        'events': [
          if (saved) {'id': eventId, 'title': 'Demo Event'},
        ],
      };
    }
    if (path == 'bookmark') {
      if (failWrite) throw const ApiFailure('Demo Speichern fehlgeschlagen');
      bodies.add(body!);
      final next = body['saved'] == true;
      if (next != saved) count += next ? 1 : -1;
      saved = next;
      return {'saved': saved, 'interest_count': public ? count : null};
    }
    if (path == 'events/$eventId') {
      return {
        ...events.first,
        'signed_in': loggedIn,
        'interest_count': public ? count : null,
      };
    }
    return super.directory(path, query: query, body: body);
  }
}

void main() {
  testWidgets(
    'compact bookmark keeps its accessible label, target size and anonymous login boundary',
    (tester) async {
      final api = InterestFixture();
      var opened = false;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: BookmarkButton(
                  api: api,
                  kind: 'event',
                  id: eventId,
                  signedIn: false,
                  compact: true,
                  openAccount: () async {
                    opened = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byType(AccessAction);
        expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Anmelden und merken'), findsWidgets);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(opened, isTrue);
        expect(api.calls, isEmpty);
        expect(api.bodies, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'anonymous public interest count does not load personal bookmarks and offers sign-in',
    (tester) async {
      final api = InterestFixture();
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkButton(
              api: api,
              kind: 'event',
              id: eventId,
              signedIn: false,
              interestCount: 12,
              openAccount: () async {
                opened = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12 Personen interessiert'), findsOneWidget);
      expect(api.calls, isEmpty);
      await tester.tap(find.text('Anmelden und merken'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    },
  );

  testWidgets(
    'event bookmark changes the actual server count and failed writes keep it unchanged',
    (tester) async {
      final api = InterestFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkButton(
              api: api,
              kind: 'event',
              id: eventId,
              interestCount: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event merken'));
      await tester.pumpAndSettle();
      expect(find.text('1 Person interessiert'), findsOneWidget);
      expect(api.bodies.last, {'kind': 'event', 'id': eventId, 'saved': true});
      api.failWrite = true;
      await tester.tap(find.text('Aus Merkliste entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('1 Person interessiert'), findsOneWidget);
      expect(find.text('Demo Speichern fehlgeschlagen'), findsOneWidget);
      api.failWrite = false;
      // A failed response must be reconciled before a second write.
      await tester.tap(find.text('Aktualisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aus Merkliste entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('0 Personen interessiert'), findsOneWidget);
    },
  );

  testWidgets(
    'private event has no public count and is listed only in the personal bookmarks',
    (tester) async {
      final api = InterestFixture()..public = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkButton(api: api, kind: 'event', id: eventId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Event merken'));
      await tester.pumpAndSettle();
      expect(find.textContaining('interessiert'), findsNothing);
      await tester.pumpWidget(MaterialApp(home: BookmarksPage(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Demo Event'), findsOneWidget);
      await tester.tap(find.text('Ansehen'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('events/$eventId'));
    },
  );

  for (final size in [const Size(320, 900), const Size(1280, 1000)]) {
    testWidgets(
      'event interest stays near the facts and fits $size at twice text size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = InterestFixture()
          ..count = 8
          ..loggedIn = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: AccessDesign.theme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: ProgramDetailPage(api: api, kind: 'events', id: eventId),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('8 Personen interessiert'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('8 Personen interessiert')).dy,
          lessThan(
            tester.getTopLeft(find.text('Zugänglichkeit und Awareness')).dy,
          ),
        );
        expect(api.calls, isNot(contains('bookmarks')));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
