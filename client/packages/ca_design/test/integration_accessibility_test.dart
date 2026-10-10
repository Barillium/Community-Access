import 'package:ca_design/ca_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Archivo license is bundled for the license page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final license =
        await rootBundle.loadString('packages/ca_design/fonts/OFL.txt');
    expect(license, contains('SIL OPEN FONT LICENSE'));
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final dark in [false, true]) {
      testWidgets('$platform dark=$dark navigation follows 200% system text',
          (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var selected = -1;
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(MaterialApp(
          theme: (dark ? CaTheme.dark() : CaTheme.light())
              .copyWith(platform: platform),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
              bottomNavigationBar: CaNavBar(
            currentIndex: 0,
            onSelect: (index) => selected = index,
            items: const [
              CaNavItem('Programm', Icons.calendar_today_outlined,
                  Icons.calendar_today),
              CaNavItem('Merkliste', Icons.bookmark_border, Icons.bookmark),
              CaNavItem('Mein Zugang', Icons.door_front_door_outlined,
                  Icons.door_front_door),
              CaNavItem(
                  'Konto', Icons.account_circle_outlined, Icons.account_circle),
            ],
          )),
        ));
        await tester.pumpAndSettle();
        final label = find.text('Mein Zugang');
        expect(MediaQuery.textScalerOf(tester.element(label)).scale(12), 24);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await tester.tap(label);
        expect(selected, 2);
        semantics.dispose();
      });
    }
  }
}
