import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:community_access/main.dart';
import 'package:community_access/demo_status.dart';

void main() {
  testWidgets('Starts pending and visibly labels the synthetic demo', (
    tester,
  ) async {
    await tester.pumpWidget(const CommunityAccessApp());
    expect(
      find.text('Lokale Demo · ausschließlich erfundene Daten'),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('current-status'))).data,
      'Bewerbung offen',
    );
    expect(find.text('Keine Eventzusage'), findsOneWidget);
  });

  testWidgets('Every fixture shows its separate status and confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const CommunityAccessApp());
    for (final status in DemoStatus.values.reversed) {
      await tester.tap(find.widgetWithText(ChoiceChip, status.label));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('current-status'))).data,
        status.label,
      );
      expect(find.text(status.description), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('event-confirmation'))).data,
        status == DemoStatus.eventConfirmed
            ? 'Eventzusage im Beispiel vorhanden'
            : 'Keine Eventzusage',
      );
    }
  });

  testWidgets(
    'Narrow screen and large text remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(const CommunityAccessApp());
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(DemoPage)))
            .scale(16),
        32,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Mitgliedschaft ist keine Eventbestätigung.'),
        150,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Demo choices can be reached and activated by keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(const CommunityAccessApp());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('current-status'))).data,
      'Aufgenommen',
    );
    expect(find.text('Keine Eventzusage'), findsOneWidget);
  });
}
