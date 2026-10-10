import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:community_access_client/app_language.dart';
import 'package:community_access_client/appearance_scope.dart';
import 'package:community_access_client/design_system.dart';
import 'package:community_access_client/main.dart';
import 'package:community_access_client/public_home_page.dart';

import 'discovery_widget_test.dart' show DiscoveryFixture;

void main() {
  for (final size in [
    const Size(320, 900),
    const Size(375, 812),
    const Size(700, 375),
  ]) {
    testWidgets(
      'account settings retain theme, language and login return at $size with enlarged text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(
          tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
        );
        final api = DiscoveryFixture();
        await tester.pumpWidget(
          CommunityAccessApp(api: api, authOnly: true, showPublicHome: true),
        );
        await tester.pumpAndSettle();
        final homeContext = tester.element(find.byType(PublicHomePage));
        final language = LanguageScope.of(homeContext)!;
        final appearance = AppearanceScope.of(homeContext)!;
        expect(find.byTooltip('Sprache wählen'), findsNothing);
        await tester.tap(find.text('Konto').last);
        await tester.pumpAndSettle();
        expect(find.text('Sprache'), findsOneWidget);
        final dark = find.text('Dunkle Darstellung');
        await tester.ensureVisible(dark);
        await tester.tap(dark);
        await tester.pumpAndSettle();
        expect(appearance.value, ThemeMode.dark);
        expect(tester.takeException(), isNull);
        final english = find.text('English');
        await tester.ensureVisible(english);
        await tester.tap(english);
        await tester.pumpAndSettle();
        expect(language.value, isTrue);
        expect(find.text('Appearance'), findsOneWidget);
        await tester.ensureVisible(find.byTooltip('Close account menu'));
        await tester.tap(find.byTooltip('Close account menu'));
        await tester.pumpAndSettle();
        expect(find.text('Appearance'), findsNothing);
        expect(api.writes, isEmpty);
        await tester.tap(find.text('Account').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sign in'));
        await tester.tap(find.text('Sign in'));
        await tester.pumpAndSettle();
        expect(find.byType(GuestPage), findsOneWidget);
        final back = find.text('Back to home');
        await tester.ensureVisible(back);
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(find.byType(GuestPage), findsNothing);
        expect(find.text('Appearance'), findsNothing);
        expect(api.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'touch does not retain mouse hover; keyboard and reduced motion remove action displacement',
    (tester) async {
      var calls = 0;
      bool reduced = false;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: AccessDesign.theme(),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(disableAnimations: reduced),
                child: Scaffold(
                  body: Center(
                    child: AccessAction(
                      kind: AccessActionKind.primary,
                      onPressed: () => calls++,
                      child: const Text('Öffnen'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.byType(AccessAction);
      final button = find.byType(FButton);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(action));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(button) - tester.getTopLeft(action),
        const Offset(-3, -3),
      );
      tester.widget<FButton>(button).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.getTopLeft(button), tester.getTopLeft(action));
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(action));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tester.getTopLeft(button), tester.getTopLeft(action));
      rebuild(() => reduced = true);
      await tester.pumpAndSettle();
      await mouse.moveTo(Offset.zero);
      await mouse.moveTo(tester.getCenter(action));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(button), tester.getTopLeft(action));
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
    },
  );
}
