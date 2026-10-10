import 'dart:math' as math;

import 'package:ca_design/ca_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= .04045 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
    return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + .05) / (math.min(l1, l2) + .05);
}

void main() {
  for (final (name, c) in [
    ('hell', CaColors.light),
    ('dunkel', CaColors.dark)
  ]) {
    test('Kontrast $name', () {
      expect(_contrast(c.textPrimary, c.surfacePage), greaterThanOrEqualTo(7));
      expect(
          _contrast(c.textSecondary, c.surfacePage), greaterThanOrEqualTo(4.5));
      expect(
          _contrast(c.textDecision, c.surfacePage), greaterThanOrEqualTo(4.5));
      expect(_contrast(c.actionOnPrimary, c.actionPrimary),
          greaterThanOrEqualTo(4.5));
      expect(
          _contrast(c.textInverse, c.surfaceInverse), greaterThanOrEqualTo(7));
    });
  }

  testWidgets('Bausteine bauen in hell und dunkel, Ziele mindestens 48',
      (tester) async {
    for (final theme in [CaTheme.light(), CaTheme.dark()]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: ListView(children: [
            EventRow(
                title: 'Lesung',
                when: 'Sa 28.11.',
                access: CaAccess.semi,
                placeLocked: true,
                saved: false,
                onSaved: (_) {}),
            const EmbossedLock(label: 'Genauer Ort'),
            const DoorList(steps: [
              DoorStep('Zugesagt', state: DoorState.done),
              DoorStep('Ort folgt', state: DoorState.now)
            ]),
          ]),
          bottomNavigationBar: CaNavBar(
            currentIndex: 0,
            onSelect: (_) {},
            items: const [
              CaNavItem('Programm', Icons.calendar_today_outlined,
                  Icons.calendar_today),
              CaNavItem('Merkliste', Icons.bookmark_border, Icons.bookmark),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ort nach Zusage'), findsOneWidget);
      expect(tester.getSize(find.byType(CaSaveButton)).height,
          greaterThanOrEqualTo(48));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    }
  });
}
