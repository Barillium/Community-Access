@Tags(['v1'])
library;

import 'package:community_access_client/bookmark_views.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/product_scope.dart';
import 'package:community_access_client/site_information_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

void main() {
  test('default product scope is valid V1', () {
    expect(ProductScope.valid, isTrue);
    expect(ProductScope.extended, isFalse);
  });
  test(
    'V1 privacy draft describes actual scope and preserves financial records',
    () {
      expect(
        privacyInformation,
        contains('Bestellnachweise und offene Erstattungen'),
      );
      expect(
        privacyInformation,
        isNot(contains('Gäste können freiwillig Veranstaltungspräferenzen')),
      );
      expect(
        privacyInformation,
        isNot(
          contains(
            'werden bei der nächsten Bereinigung aus der aktiven lokalen Datenbank gelöscht',
          ),
        ),
      );
    },
  );
  testWidgets('V1 mobile entry omits deferred navigation and filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = DiscoveryFixture();
    api.events.removeWhere((e) => e['access_mode'] == 'semi_public');
    await tester.pumpWidget(
      CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Merkliste'), findsNothing);
    expect(find.text('Veranstaltungsorte'), findsNothing);
    expect(find.text('Semi-öffentlich'), findsNothing);
    expect(find.text('Meine Präferenzen'), findsNothing);
    await tester.tap(find.byTooltip('Menü'));
    await tester.pumpAndSettle();
    expect(find.text('Merkliste'), findsNothing);
    expect(find.text('Orte'), findsNothing);
    expect(find.text('Mein Zugang'), findsOneWidget);
    expect(find.text('Konto und Darstellung'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('V1 bookmark and interest widgets perform no deferred requests', (
    tester,
  ) async {
    final api = DiscoveryFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BookmarkButton(api: api, kind: 'event', id: 'one'),
              const InterestCount(count: 123),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('interessiert'), findsNothing);
    expect(api.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
