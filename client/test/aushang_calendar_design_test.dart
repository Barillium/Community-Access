import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/program_views.dart';
import 'package:community_access_client/event_carousel.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

void main() {
  for (final size in [
    const Size(320, 900),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets(
      'calendar grouping, filters and search retain authorized data at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = DiscoveryFixture();
        api.events.first['access_mode'] = 'public';
        api.events.last['starts_at'] = '2026-11-01T22:00:00Z';
        await tester.pumpWidget(
          CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
        );
        await tester.pumpAndSettle();
        final program = find.byType(ProgramList);
        Finder rowTitle(String title) => find.descendant(
          of: program,
          matching: find.text(title.toUpperCase()),
        );
        expect(rowTitle('Demo Ambientabend'), findsOneWidget);
        expect(rowTitle('Demo Secret Night'), findsOneWidget);
        final semantics = tester.ensureSemantics();
        final openEvent = tester.getSemantics(
          find.bySemanticsLabel('Event ansehen: Demo Ambientabend'),
        );
        expect(openEvent.flagsCollection.isButton, isTrue);
        expect(openEvent.flagsCollection.isHeader, isFalse);
        semantics.dispose();
        if (size.width >= 1280) {
          expect(
            find.descendant(of: program, matching: find.text('Sonntag')),
            findsOneWidget,
            reason: 'Two events on one day share one date column.',
          );
        }
        final publicFilter = find
            .ancestor(
              of: find.text('Öffentlich'),
              matching: find.byType(TextButton),
            )
            .first;
        await tester.ensureVisible(publicFilter);
        await tester.tap(publicFilter);
        await tester.pumpAndSettle();
        expect(rowTitle('Demo Ambientabend'), findsOneWidget);
        expect(rowTitle('Demo Secret Night'), findsNothing);
        final semiFilter = find
            .ancestor(
              of: find.text('Semi-öffentlich'),
              matching: find.byType(TextButton),
            )
            .first;
        await tester.tap(semiFilter);
        await tester.pumpAndSettle();
        expect(rowTitle('Demo Ambientabend'), findsNothing);
        expect(rowTitle('Demo Secret Night'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EventCarousel),
            matching: find.text('DEMO AMBIENTABEND'),
          ),
          findsOneWidget,
          reason: 'A program filter does not replace the carousel selection.',
        );
        final search = find.byTooltip('Suche öffnen').last;
        await tester.ensureVisible(search);
        await tester.tap(search);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Demo');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(rowTitle('Demo Ambientabend'), findsNothing);
        expect(rowTitle('Demo Secret Night'), findsOneWidget);
        expect(api.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
