import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/event_carousel.dart';
import 'package:community_access_client/event_editorial_view.dart';
import 'package:community_access_client/event_hero_metadata.dart';

import 'event_editorial_test.dart' show demoEvent;

void main() {
  test('community metadata prefers explicit assignments and ignores editorial tags', () {
    expect(
      eventHeroCommunities({'external': true, 'community': 'Editorial tag'}),
      isEmpty,
    );
    expect(eventHeroCommunities({'community': 'Legacy public community'}), [
      'Legacy public community',
    ]);
    expect(
      eventHeroCommunities({
        'community': 'Stale legacy name',
        'communities': [],
      }),
      isEmpty,
    );
    expect(
      eventHeroCommunities({
        'communities': [
          {'id': 'demo-a', 'name': 'Demo A'},
          {'id': 'demo-a', 'name': 'Demo A duplicate'},
          {'id': 'demo-b', 'name': 'Demo B'},
          {'name': 'Unassigned'},
        ],
      }),
      ['Demo A', 'Demo B'],
    );
  });
  testWidgets('missing and invalid prices never imply free admission', (
    tester,
  ) async {
    for (final price in [null, -1, double.nan]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventHeroMetadata(
              event: {'ticket_price_cents': price, 'ticket_mode': 'public'},
            ),
          ),
        ),
      );
      expect(find.text('Noch nicht angegeben'), findsOneWidget);
      expect(find.text('0,00 €'), findsNothing);
    }
  });
  testWidgets('external qualifiers and fees remain intact', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventHeroMetadata(
            event: {
              'external': true,
              'community': 'Not a registered assignment',
              'event_content': {
                'ticket_price_label_de': 'ab 10 € zzgl. Gebühren · Vorverkauf',
              },
            },
          ),
        ),
      ),
    );
    expect(find.text('ab 10 € zzgl. Gebühren · Vorverkauf'), findsOneWidget);
    expect(find.text('Keine Community angegeben'), findsOneWidget);
    expect(find.text('Not a registered assignment'), findsNothing);
  });
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final english in [false, true]) {
      for (final carousel in [false, true]) {
        testWidgets('hero metadata $width / EN=$english / carousel=$carousel', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final language = AppLanguage()..value = english;
          addTearDown(language.dispose);
          final event = {
            ...demoEvent(),
            'id': 'synthetic-event',
            'ticket_mode': 'public',
            'ticket_price_cents': 1250,
            'communities': [
              {
                'id': 'demo-a',
                'name':
                    'Demo community for independent culture and open workshops',
              },
              {'id': 'demo-b', 'name': 'Demo B'},
            ],
          };
          await tester.pumpWidget(
            LanguageScope(
              language: language,
              child: MaterialApp(
                theme: AccessDesign.theme(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      width == 390 && english ? 2 : 1,
                    ),
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: carousel
                        ? EventCarousel(events: [event], onOpen: (_) {})
                        : EventEditorialView(event: event),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(english ? '€12.50' : '12,50 €'), findsOneWidget);
          expect(
            find.text(
              'Demo community for independent culture and open workshops · Demo B',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
